import sys
from PIL import Image
import os
import math


valid_extensions = [".jpg", ".jpeg", ".png", ".webp"]
WEBP_LIMIT = 16000  # (actual limit is 16383)


def usage(error=""):
    print(f"""
Usage: python main.py <Image 1> <Image 2> ...

Or

Usage: python main.py <Directory>

Valid extensions: {valid_extensions}
""")
    print("ERROR:", error)


def filter_files(filenames):
    filtered = []

    # check if every file exists and is an image
    for file in filenames:
        if not os.path.isfile(file):
            continue

        _, file_extension = os.path.splitext(file)

        if file_extension not in [ext.lower() for ext in valid_extensions]:
            continue

        filtered.append(file)

    return filtered


def main():
    # if 2, must be Directory
    if len(sys.argv) == 2:
        directory = sys.argv[1]

        if not os.path.isdir(directory):
            return usage("Not a valid directory.")

        full_paths = []
        for filename in os.listdir(directory):
            full_paths.append(os.path.join(directory, filename))

        list = filter_files(full_paths)

        if len(list) <= 1:
            return usage("Directory should have atleast 2 images.")

        stitch_images(list)

    # if more, must be seperate images
    else:
        files = sys.argv[1:]
        list = filter_files(files)

        if len(list) <= 1:
            return usage(
                "A given image either does not exist or does not have a valid extension."
            )

        stitch_images(files)


def stitch_images(file_paths):
    """
     How it works:
    1. Gets the minimum width from all images.
    2. Resizes the image, to match the min width
    3. Checks if
    """

    # Open all images and convert to RGB
    images = [Image.open(path).convert("RGB") for path in file_paths]

    min_width = min(img.width for img in images)

    # Resize images
    resized_images = []
    for img in images:
        w_percent = min_width / float(img.width)
        h_size = int(float(img.height) * float(w_percent))
        resized_img = img.resize((min_width, h_size), Image.Resampling.LANCZOS)
        resized_images.append(resized_img)

    total_height = sum(img.height for img in resized_images)

    if total_height <= WEBP_LIMIT:
        first_image_dir = os.path.dirname(file_paths[0])
        base_name = "stitched_output.webp"
        output_path = os.path.join(first_image_dir, base_name)

        # case when output file already exists
        counter = 1
        while os.path.exists(output_path):
            base_name = f"stitched_output_{counter}.webp"
            output_path = os.path.join(first_image_dir, base_name)
            counter += 1

        # creates image
        stitched_image = Image.new("RGB", (min_width, total_height))
        y_offset = 0
        for img in resized_images:
            stitched_image.paste(img, (0, y_offset))
            y_offset += img.height

        stitched_image.save(output_path, "WEBP", quality=90)
        return print(f"Stitched image saved to {output_path}.")

    else:
        # if over limit, split the total height into even parts
        image_count = len(resized_images)

        split = 2
        split_array = []
        largest_image = WEBP_LIMIT + 1
        while largest_image > WEBP_LIMIT:
            images_per_split = image_count // split
            split_array.clear()

            # check for the largest split
            heights = []
            start_index = 0

            for i in range(split):
                end_index = start_index + math.ceil(images_per_split)
                # if last split image
                if i == split - 1:
                    end_index = image_count

                split_height = sum(
                    img.height for img in resized_images[start_index:end_index]
                )

                heights.append(split_height)
                split_array.append([start_index, end_index])

                start_index = end_index

            largest_image = max(heights)

            if largest_image > WEBP_LIMIT:
                split += 1

        first_image_dir = os.path.dirname(file_paths[0])
        output_path = os.path.join(first_image_dir, "stitched_output_")

        # create images
        for i in range(split):
            index_range = split_array[i]
            images = resized_images[index_range[0] : index_range[1]]
            stitched_image = Image.new(
                "RGB", (min_width, sum(img.height for img in images))
            )

            y_offset = 0
            for img in images:
                stitched_image.paste(img, (0, y_offset))
                y_offset += img.height

            stitched_image.save(f"{output_path}_{i + 1}.webp", "WEBP", quality=90)
            print(f"Image part {i+1} saved to {output_path}.")


if __name__ == "__main__":
    main()
