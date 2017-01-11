#!/usr/bin/env python
# _*_ coding:utf-8 _*_

'''
created on 2016-12-28
@author: kimilin

Test on Mac OSX 10.12.1
May require OSX 10.9 and latter
'''
import subprocess
import sys
import os
import shutil
import tempfile
import plistlib


# LACK_ARGHMENT = 1
# PAYLOAD_NOEXISTS = 2
# INFOPLIST_NOTEXISTS = 3
# EMBEDED_PP_NOTEXISTS = 4

def __handle_error_lines(process, cmd, inlistformate = False):
	'''
	@brief 处理命令行输出
	'''
	if not process:
		return None
	lines = process.stderr.readlines() if process.stderr else None
	if lines:
		feedback = ''
		for s in lines:
			feedback += s
		raise Exception('Execute cmd Error: %s' % cmd)
	else:
		lines = process.stdout.readlines()
		if inlistformate:
			lines = map(lambda s: s.strip(), lines) # delete '\n'
			lines = filter(lambda s: s, lines)
			return lines # filter empty
		else:
			feedback = ''
			for line in lines:
				if not isinstance(line, str):
					try:
						line = str(line)
					except :
						raise Exception('feedback line can not convert to str')
				feedback += line
			return feedback

def execute_cmd(cmd, getfeedback = True):
	'''
	@brief 执行普通的命令行指令
	@param cmd: 命令
	@param getfeedback 是否返回输出
	@param inlistformate False输出以str类型返回，True输出以list类型返回
	'''
	out_temp = tempfile.SpooledTemporaryFile(bufsize=100)
	fileno = out_temp.fileno()
	process = subprocess.Popen(cmd, shell = True, stdout = fileno, stderr = fileno)
	process.wait()
	if getfeedback:
		out_temp.seek(0)
		lines = out_temp.readlines()
		feedback = ''
		for line in lines:
			feedback += line
		return feedback
	else:
		return process


class Resigner(object):
	"""Resign a ipa"""
	def __init__(self, ipaPath, resourcePathes, newProfilePath, newBundleId, cerSHA, cerName, workDir):
		super(Resigner, self).__init__()
		self.ipaPath = ipaPath
		self.resourcePathes = resourcePathes
		self.replacePPFilePath = newProfilePath
		self.newBundleId = newBundleId
		self.cerSHA = cerSHA
		self.cerName = cerName
		self.workDir = workDir
		
	def resign(self):
		self.unzipIPA()
		self.replacePPFIleIfNeed()
		self.generateEntitlements()
		self.modifyBundleIdIfNeed()

		self.checkSignCondition()

		self.replaceResourceIfNeed()
		self.forceSign()
		self.verifySignature()
		self.packIPA()
		self.cleanUp()
		

	def checkSignCondition(self):
		# 检查Info.plist的bundleId与描述文件的BundleId是否一致
		# 检查描述文件和证书是否匹配
		print('\nChecking matches...')
		cmd = 'security cms -D -i %s' % self.embedPath
		embeddedInfo = execute_cmd(cmd)

		toDelete = "security: SecPolicySetValue: One or more parameters passed to a function were not valid.\n"
		if toDelete in embeddedInfo:
			embeddedInfo = embeddedInfo.replace(toDelete,'')

		pl = plistlib.readPlistFromString(embeddedInfo)
		embeddedTeamId = pl['Entitlements']['com.apple.developer.team-identifier']
		embeddedBundleId = pl['Entitlements']['application-identifier']
		embeddedBundleId = embeddedBundleId.replace(embeddedTeamId+'.','')

		# verify Profile match Certificate or not
		if self.cerName.find(')') > 0:
			import re
			# 'iPhone Distribution: lian wen (5QVFGL3BHF)'
			match = re.search(r'(\([\w\d]+\))', self.cerName)
			if match:
				cerTeamId = match.group()[1:-1]
				if cerTeamId == embeddedTeamId:
					print('embedded.mobileprovision match certificate')
				else:
					raise Exception('描述文件与证书不匹配, 描述文件Team-Id:%s, 证书Team-Id:%s，请检查证书是否选择正确' % (embeddedTeamId, cerTeamId))
			else:
				raise Exception("无法从证书\"%s\"中匹配到TeamId" % self.cerName)

		# verify Profile BundleId match Info.plist or not

		if embeddedBundleId != self.infoBundleId:
			raise Exception('描述文件BundleId:\"%s\" 与Info.plist的bundleId:\"%s\"不匹配' %(embeddedBundleId, self.infoBundleId))
		print('Profile matches Cer, bundleId matches')
		
	def unzipIPA(self):
		targetPath = os.path.join(self.workDir,'IPA.zip')
		cmd = r'cp %s %s' % (self.ipaPath, targetPath)
		# copy as zip
		print('coping IPA')
		execute_cmd(cmd)

		# remove Payload if exits
		self.payload = os.path.join(os.path.dirname(targetPath), 'Payload')
		symbolsPath = os.path.join(os.path.dirname(targetPath), 'Symbols')

		if os.path.exists(self.payload) and os.path.isdir(self.payload):
			print('remove old Payload')
			shutil.rmtree(self.payload, ignore_errors=True)

		if os.path.exists(symbolsPath) and os.path.isdir(symbolsPath):
			print('remove old Symbols')
			shutil.rmtree(symbolsPath, ignore_errors=True)

		# upzip quiet
		print('unzip file...')
		cmd = 'cd %s;unzip -q %s' % ( os.path.dirname(targetPath), targetPath )
		feedback = execute_cmd(cmd)
		
		if os.path.exists(self.payload) and os.path.isdir(self.payload):
			
			# 可能存在Symbols文件夹，重签名后需要与Payload一起压缩
			if os.path.exists(symbolsPath) and os.path.isdir(symbolsPath):
				self.symbols = symbolsPath

			for file in os.listdir(self.payload):
				if file.endswith('.app'):
					self.appPath = os.path.join(self.payload,file)

			self.infoPlistPath = os.path.join(self.appPath,'Info.plist')
			self.embedPath = os.path.join(self.appPath,'embedded.mobileprovision')
			# delete zip file
			os.remove(targetPath)

			result = os.path.exists(self.infoPlistPath)
			if not result:
				raise Exception('缺少Info.plist文件:%s' % self.infoPlistPath)

			result = os.path.exists(self.embedPath)
			if not result:
				raise Exception('缺少embedded.mobileprovision:%s' % self.embedPath)

			print('unziping file success')
		else:
			print('unziping file fail')
			raise Exception('解压失败，无法找到Payload文件夹')

	def replacePPFIleIfNeed(self):
		print('\nReplacing PPFile...')
		if len(self.replacePPFilePath) > 0:
			print('replacing PP file...')
			if os.path.exists(self.replacePPFilePath):
				cmd = r'cd %s;cp %s %s' % (self.appPath, self.replacePPFilePath, os.path.join(self.appPath,'embedded.mobileprovision'))
				feedback = execute_cmd(cmd)
				if len(feedback) > 0:
					print cmd
					print feedback
					raise Exception('复制描述文件失败:%s' % feedback)
				else:
					print('replace PP file success')
			else:
				raise Exception('用于替换的描述文件不存在，请检查:%s' % self.replacePPFilePath)
		else:
			print('No need to replace PP file')
		
	def generateEntitlements(self):
		print('\nGenerating entitlements.plist...')
		if os.path.exists(self.embedPath):
			print('Generate entitlements...')
			tempPlistPath = os.path.join(self.workDir, 'temp.plist')
			if os.path.exists(tempPlistPath):
				os.remove(tempPlistPath)
			self.entitlements = os.path.join(self.workDir,'entitlements.plist')
			cmd = 'security cms -D -i %s > %s' % (self.embedPath, tempPlistPath)
			execute_cmd(cmd)
			try:
				tempPlist = plistlib.readPlist(tempPlistPath)
			except Exception, e:
				raise Exception('读取plist文件失败：%s' % e)
			entitlements = tempPlist['Entitlements']
			try:
				plistlib.writePlist(entitlements, self.entitlements)
			except Exception, e:
				os.remove(tempPlistPath)
				raise Exception('写入Plist失败:%s' % e)
			os.remove(tempPlistPath)
			print('Generate entitlements success')
		else:
			print('embedded.mobileprovision not exists')
			raise Exception('缺少embedded.mobileprovision:%s' % self.embedPath)

	def modifyBundleIdIfNeed(self):
		print('\nModifying BundleId...')
		if len(self.newBundleId) > 0:

			# CFBundleIdentifier
			print('modify CFBundleIdentifier...')
			cmd = "/usr/libexec/PlistBuddy -c \"Set CFBundleIdentifier %s\" %s" % (self.newBundleId, self.infoPlistPath)
			feedback = execute_cmd(cmd)
			if len(feedback) < 1:
				print('modify CFBundleIdentifier success')
				# softwareVersionBundleId
				cmd = "/usr/libexec/PlistBuddy -c \"Print softwareVersionBundleId\" %s" % self.infoPlistPath
				feedback = execute_cmd(cmd)
				if 'Does Not Exist' in feedback:
					print('No need to modify softwareVersionBundleId')
				else:
					cmd = "/usr/libexec/PlistBuddy -c \"Set softwareVersionBundleId %s\" %s" % (self.newBundleId, self.infoPlistPath)
					feedback = execute_cmd(cmd)
					if len(feedback) < 1:
						print('modify CFBundleIdentifier success')
					else:
						print(feedback)
						raise Exception('修改iTunes资料BundleId失败:%s' % feedback)
				self.infoBundleId = self.newBundleId
		else:
			print('No need to modify BundleIds')
			cmd = "/usr/libexec/PlistBuddy -c \"Print CFBundleIdentifier\" %s" % self.infoPlistPath
			feedback = execute_cmd(cmd)
			feedback = feedback.strip()
			self.infoBundleId = feedback

		print('Info BundleId:\"%s\"' % self.infoBundleId)

	def replaceFile(self, directory, targetFilePathes):
		for file in os.listdir(directory):
			if len(targetFilePathes) < 1:
				break
			filePath = os.path.join(directory, file)
			if os.path.isdir(filePath):
				self.replaceFile(filePath, targetFilePathes)
			else:
				for targetPath in targetFilePathes:
					if file == os.path.basename(targetPath):
						print('replace resource:%s in %s' % (file, directory))
						shutil.copy2(targetPath, directory)
						targetFilePathes.remove(targetPath)
						break

	def replaceResourceIfNeed(self):
		print('\nReplacing resource files...')
		try:
			if len(self.resourcePathes) > 1:
				filePathes = filter(lambda s: s, self.resourcePathes.split(','))
				return self.replaceFile(self.appPath, filePathes)
			else:
				print('No need to replace resource')
		except Exception, e:
			raise Exception('替换资源文件失败:%s' % e)

	def forceSign(self):
		print('\nForce signning...')

		signPath = 'Payload/' + os.path.basename(self.appPath)
		cmd = 'cd %s;codesign -f -s \"%s\" --no-strict --entitlements %s %s' % (self.workDir, self.cerSHA, self.entitlements, signPath)
		feedback = execute_cmd(cmd)
		
		check = '%s: replacing existing signature\n' % signPath
		if feedback == check:
			print feedback.strip()
			print('force sign success')
		else:
			print feedback
			raise Exception('签名失败:%s' % feedback)

	def verifySignature(self):
		print('\nVerifying signature')
		cmd = 'codesign -v %s' % self.appPath
		feedback = execute_cmd(cmd).strip()
		if len(feedback) > 0:
			raise Exception('签名验证失败:%s' % feedback)
		else:
			print('Verify signature success')


	def packIPA(self):
		# -q --quiet
		# -r --recurse-paths:Travel the directory structure recursively
		# -y --symlinks
		print('\nPacking IPA...')
		baseName = os.path.basename(self.ipaPath).split('.')[0] + '-resigned.ipa'
		baseDir = os.path.dirname(self.ipaPath)
		targetPath = os.path.join(baseDir, baseName)
		if self.symbols:
			cmd = 'cd %s;zip -qry %s %s %s' % (self.workDir, targetPath, os.path.basename(self.payload), os.path.basename(self.symbols))
		else:
			cmd = 'cd %s;zip -qry %s %s' % (self.workDir, targetPath, os.path.basename(self.payload))
		print cmd
		feedback = execute_cmd(cmd)
		feedback = feedback.strip()
		if len(feedback) > 0:
			print feedback
			raise Exception('打包IPA失败:%s' % feedback)
		else:
			print('Pack IPA Success')

	def cleanUp(self):
		print('\nCleaning up')
		if os.path.exists(self.workDir):
			shutil.rmtree(self.workDir)


if __name__ == '__main__':
	def testResign():
		ipaPath = '/Users/kimilin/Downloads/zigong_Release_Distribution.ipa'
		resourcePathes = ''
		embedPath = ''
		newBundleId = ''
		cerSHA = '141E0CB07AA54766664EBEB32F48E99A957362EE'
		cerName = 'iPhone Distribution: Guangjiu Zhao (7QMD9LVCM8)'
		workDir = '/var/folders/4f/slhnzjnn7_jb1sj6gfmb3jtr0000gp/T/BYResign'
		if not os.path.exists(workDir):
			os.mkdir(workDir)
		rsg = Resigner(ipaPath, resourcePathes, embedPath, newBundleId, cerSHA, cerName, workDir)
		rsg.resign()

	reload(sys)
	sys.setdefaultencoding('utf8')
	try:
		args = sys.argv
		ipaPath = args[1]
		resourcePathes = args[2]
		embedPath = args[3]
		newBundleId = args[4]
		cerSHA = args[5]
		cerName = args[6]
		workDir = args[7]
	except:
		raise Exception('缺少必要参数，请检查,argv = %s' % args)
	else:
		rsg = Resigner(ipaPath, resourcePathes, embedPath, newBundleId, cerSHA, cerName, workDir)
		try:
			rsg.resign()
		except Exception, e:
			rsg.cleanUp()
			raise e
        



