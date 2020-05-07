To Export video files:
- Download ffmpeg for Mac: https://evermeet.cx/ffmpeg/getrelease/zip
- Unzip the file, place "ffmpeg" here in the export folder
- Run EnvelopLX in processing, set resolution to 720 using the button, use the recording toggle to export frames

After that:
- Open Mac Terminal
- cd ~/Documents/Processing/EnvelopLX/EnvelopLX/export
- ./encode.sh <export folder>
- Example: ./encode.sh 2020-05-06-18.38.16
- NOTE - Make sure there is no trailing slash!
- Video file will be 2020-05-06-18.38.16.mov
