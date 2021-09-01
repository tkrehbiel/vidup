This is a command-line tool written in Golang that uses the YouTube Data API to upload a video file to a channel.

It's intended to be used in command-line scripts to automate the process of uploading a large number of video files to a channel over a long period of time, for example, one or two videos a day. It's not meant to upload a lot of files at once.

The idea is to schedule a script to run once a day, which looks into a directory of video files, finds the next one that needs to be uploaded, then runs this "vidup" command which authenticates to YouTube and uploads that one video file with suitable metadata.

Some manual user intervention may be required from time to time to authenticate YouTube credentials through a web browser.

The code for vidup is based almost entirely on [Google's YouTube Data API example golang code](https://developers.google.com/youtube/v3/code_samples/go).

Some inspiration also from https://github.com/porjo/youtubeuploader.
