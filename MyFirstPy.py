import os
import io
import re
from codecs import open



def generateLogDatasets(logoutputfile, filenameoutputfile):

	filelist = os.walk(".")

	logpattern = re.compile("[Ll]og\w{5,11}\(") #Find patterns where we see the log method invoked (capital and lowercase L)
	commentpattern = re.compile("^\s{0,}\/\/") #Find patterns where the entire line is commented out
	functionpattern = re.compile("^\s{0,}private|public|static")


	outputfile = open(logoutputfile, "w") #open("result.csv", "w")
	filesfile = open(filenameoutputfile, "w")
	logfile = open("runlog.txt", "w")

	#print("FileName\tLogMessage\tLevel\tLineNumber")
	outputfile.write("FileName,LogMessage,Level,LineNumber\n")
	filesfile.write("FileName\n")

	for root, dirs, files in filelist:
		for name in files:
			if name.endswith(".cs") or name.endswith(".aspx"):
				file_object = open(os.path.join(root, name), "r", encoding="utf8", errors="replace")
				#print("Reading " + file_object.name + "...")
				try:
					for num, line in enumerate(file_object, 1):
						try:
							if re.search(logpattern, line) and not re.search(commentpattern, line) and not re.search(functionpattern, line):
								theMatch = re.search(logpattern, line)
								line = line.replace("\"", "\"\"")
								startfrom = line.find(theMatch.group(0))+len(theMatch.group(0))
								endat = line.find(");")
								outputfile.write(file_object.name + ",\"" + line[startfrom:endat] + "\"," + theMatch.group(0)[3:-1] + "," + str(num) + "\n")
						except UnicodeDecodeError:
							logfile.write("Had a problem with " + file_object.name + ", line " + str(num) + ", so skipping...\n")
				except UnicodeDecodeError as ex:
					logfile.write("Had a problem with " + file_object.name + ", so skipping...\n\t\t" + str(ex) + "\n")
				filesfile.write(file_object.name + "\n")
				file_object.close()
	outputfile.close()

generateLogDatasets("result.csv", "fileresult.csv")