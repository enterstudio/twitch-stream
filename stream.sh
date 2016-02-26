#!/bin/bash

set -eu -o pipefail

STREAM_KEY=$(cat "$(dirname "$0")/key.secret")

INRES="1366x768"  # input resolution
OUTRES=$INRES     # output resolution
FPS="15"          # target FPS
THREADS="6"       # max 6
CBR="1000k"       # constant bitrate (should be between 1000k - 3000k)
QUALITY="ultrafast" # or 'fast', 'medium', 'slow', ...
AUDIO_RATE=11025  # 44100
SERVER="live"

GOP=`expr $FPS \* 2` # i-frame interval, should be double of FPS, 
GOPMIN=$FPS          # min i-frame interval, should be equal to FPS

screen=0:v
screen_opts="-f x11grab -thread_queue_size 1024 -s $INRES -r $FPS -i :0.0"

webcam=1:v
webcam_opts="-f v4l2 -thread_queue_size 1024 -video_size 320x240 -framerate $FPS -i /dev/video0"

filter="
  [$screen]setpts=PTS-STARTPTS[bg];
  [$webcam]setpts=PTS-STARTPTS,split=2[webcam1][webcam2];
  [webcam1]edgedetect=high=0.3:low=0.2,smartblur[alpha];
  [webcam2][alpha]alphamerge[fg];
  [bg][fg]overlay=W-w:H-h[out]" 

out_opts="
  -f flv
  -vcodec libx264 -g $GOP -keyint_min $GOPMIN -b:v $CBR -minrate $CBR -maxrate $CBR -pix_fmt yuv420p
  -s $OUTRES -preset $QUALITY -threads $THREADS
  -bufsize $CBR"

audio_in="-f alsa -thread_queue_size 1024 -ar $AUDIO_RATE -i hw:0"
audio_out="-strict experimental -af highpass=f=300,lowpass=f=3000 -acodec aac -map 2:a"

ffmpeg $screen_opts $webcam_opts $audio_in -filter_complex "$filter" -map "[out]" \
    $out_opts $audio_out "rtmp://$SERVER.twitch.tv/app/$STREAM_KEY" \
  2>&1 | sed "s/$STREAM_KEY/**********/"

