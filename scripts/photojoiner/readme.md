# Photo Joiner

A Python script that stitches together multiple images into a single image.

MacOS users can use the [Photo Joiner Shortcut](https://www.icloud.com/shortcuts/923386b32c0a458ab1e6405e0fed786f) to stitch together images without having to open the terminal.

## Requirements

-   Python 3
-   For shortcuts, Allow full disk access to Finder

## Usage

The input is rather stupid: a newline-separated list of image paths. But it works well enough for my needs.

```bash
python stitch_images.py "path/to/image1.jpg\npath/to/image2.jpg\npath/to/image3.jpg"
```

The output will be saved in the same directory as the first image.

It should support any image format that PIL supports. It compress the final output to WebP with a quality of 90.
