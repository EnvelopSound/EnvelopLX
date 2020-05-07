#!/bin/sh
ffmpeg -f image2 -framerate 30 -i $1/%05d.tif -c:v libx264 -preset veryslow -qp 18 -pix_fmt yuv420p $1.mov
