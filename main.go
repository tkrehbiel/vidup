package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"

	"google.golang.org/api/youtube/v3"
)

var (
	filename      = flag.String("filename", "", "Name of video file to upload")
	title         = flag.String("title", "Test Title", "Video title")
	description   = flag.String("description", "Test Description", "Video description")
	category      = flag.String("category", "20", "Video category")
	keywords      = flag.String("keywords", "", "Comma separated list of video keywords")
	privacy       = flag.String("privacy", "unlisted", "Video privacy status")
	recorded_date = flag.String("recorded", "", "Date the video was recorded")
	thumbnail     = flag.String("thumbnail", "", "Thumbnail to set for the video")
)

func main() {
	flag.Parse()

	if *filename == "" {
		log.Fatalf("You must provide a filename of a video file to upload")
	}

	client := getClient(youtube.YoutubeUploadScope)

	service, err := youtube.New(client)
	if err != nil {
		log.Fatalf("Error creating YouTube client: %v", err)
	}

	upload := &youtube.Video{

		Snippet: &youtube.VideoSnippet{
			Title:       *title,
			Description: *description,
			CategoryId:  *category,
		},
		RecordingDetails: &youtube.VideoRecordingDetails{
			RecordingDate: *recorded_date,
		},
		Status: &youtube.VideoStatus{PrivacyStatus: *privacy},
	}

	// The API returns a 400 Bad Request response if tags is an empty string.
	if strings.Trim(*keywords, "") != "" {
		upload.Snippet.Tags = strings.Split(*keywords, ",")
	}

	call := service.Videos.Insert([]string{"snippet,status,recordingDetails"}, upload)

	file, err := os.Open(*filename)
	defer file.Close()
	if err != nil {
		log.Fatalf("Error opening %v: %v", *filename, err)
	}

	response, err := call.Media(file).Do()
	if err != nil {
		log.Fatalf("Error uploading: %v", err)
	}
	videoID := response.Id

	fmt.Printf("Upload successful! Video ID: %v\n", videoID)

	// TODO:
	// add game name (not possible in API?)
	// insert into playlist (service.PlaylistItems.Insert)

	// From https://github.com/porjo/youtubeuploader
	if *thumbnail != "" {
		thumbReader, err := os.Open(*thumbnail)
		if err != nil {
			log.Fatal(err)
		}
		defer thumbReader.Close()

		log.Printf("Uploading thumbnail '%s'...\n", *thumbnail)
		_, err = service.Thumbnails.Set(videoID).Media(thumbReader).Do()
		if err != nil {
			log.Fatalf("Error making YouTube API call: %v", err)
		}
		fmt.Printf("Thumbnail uploaded!\n")
	}
}
