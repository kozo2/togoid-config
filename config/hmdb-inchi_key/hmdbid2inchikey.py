import xml.etree.ElementTree as ET
import os
os.system("wget https://hmdb.ca/system/downloads/current/hmdb_metabolites.zip")
os.system("unzip hmdb_metabolites.zip")
tree = ET.parse('hmdb_metabolites.xml')
root = tree.getroot()
f = open("hmdbid2inchikey.txt", "a")
for i in range(len(root)):
  f.write(root[i][3].text + "\t" + root[i][17].text)
f.close()
