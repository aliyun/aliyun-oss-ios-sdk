import os
import sys

reload(sys)
sys.setdefaultencoding("utf-8")

os.system('rm x*md -rf')
# os.system('ls | egrep \'^[^a-z]+\' | xargs rm -rf')
os.system('/usr/bin/split -p "-----" README.md')
os.system('ls x* | xargs -I a mv a a.md')

for fileName in os.listdir("./"):
    if fileName.startswith('x'):
        f = open(fileName, 'r')
        contents = f.readlines()
        name = ''
        for line in contents:
            if line.startswith("#"):
                name=line[2:].strip().replace(' ', '_')
                break
        w = open(name + '.md', 'wb')
        for line in contents:
            if line.startswith('---'):
                continue
            w.write(line)
        w.close()
        os.remove(fileName)
