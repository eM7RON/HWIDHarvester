HWIDHarvester is a tool designed to harvest hardware IDs from Windows devices for enablement of Windows Autopilot. It has 2 main components:

1. The HWIDHarvester.ps1 script should be packaged as a Win32 app and deployed to Windows devices. The script generates the HWID.csv file and then uses a post request to upload it to a Google Cloud function.
2. The HWIDHarvester.py script is to be run in a Python 12 Google Cloud function environment. It receives HWID.csv files from devices and then using the Google Drive API uploads them into a desired folder.