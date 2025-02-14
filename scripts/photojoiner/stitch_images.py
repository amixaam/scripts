import sys
from PIL import Image
import os

def stitch_images(input_paths):
    # Split paths by newlines and strip whitespace
    paths = [p.strip() for p in input_paths.split('\n') if p.strip()]
    
    # Open all images and convert to RGB
    images = [Image.open(path).convert('RGB') for path in paths]
    
    # Find minimum width
    min_width = min(img.width for img in images)
    
    # Resize images
    resized_images = []
    for img in images:
        w_percent = min_width / float(img.width)
        h_size = int(float(img.height) * float(w_percent))
        resized_img = img.resize((min_width, h_size), Image.Resampling.LANCZOS)
        resized_images.append(resized_img)

    # WebP size limit
    WEBP_LIMIT = 16300  # (actual limit is 16383)
    
    # Calculate total height and determine if splitting is needed
    total_height = sum(img.height for img in resized_images)
    
    # If height is within limit, save as single file
    if total_height <= WEBP_LIMIT:
        first_image_dir = os.path.dirname(paths[0])
        base_name = 'stitched_output.webp'
        output_path = os.path.join(first_image_dir, base_name)
        
        counter = 1
        while os.path.exists(output_path):
            base_name = f'stitched_output_{counter}.webp'
            output_path = os.path.join(first_image_dir, base_name)
            counter += 1
            
        stitched_image = Image.new('RGB', (min_width, total_height))
        y_offset = 0
        for img in resized_images:
            stitched_image.paste(img, (0, y_offset))
            y_offset += img.height
        stitched_image.save(output_path, 'WEBP', quality=90)
    else:
        # Split into multiple files
        part = 1
        current_height = 0
        current_images = []
        
        for img in resized_images:
            if current_height + img.height > WEBP_LIMIT:
                # Save current batch
                first_image_dir = os.path.dirname(paths[0])
                output_path = os.path.join(first_image_dir, f'stitched_output_part{part}.webp')
                
                stitched_image = Image.new('RGB', (min_width, current_height))
                y_offset = 0
                for sub_img in current_images:
                    stitched_image.paste(sub_img, (0, y_offset))
                    y_offset += sub_img.height
                stitched_image.save(output_path, 'WEBP', quality=90)
                
                # Reset for next batch
                part += 1
                current_height = img.height
                current_images = [img]
            else:
                current_height += img.height
                current_images.append(img)
        
        # Save the last batch if any images remain
        if current_images:
            first_image_dir = os.path.dirname(paths[0])
            output_path = os.path.join(first_image_dir, f'stitched_output_part{part}.webp')
            
            stitched_image = Image.new('RGB', (min_width, current_height))
            y_offset = 0
            for sub_img in current_images:
                stitched_image.paste(sub_img, (0, y_offset))
                y_offset += sub_img.height
            stitched_image.save(output_path, 'WEBP', quality=90)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python stitch_images.py INPUT_PATHS")
        print("Input paths should be newline-separated")
        sys.exit(1)
    
    # Only need the first argument now: newline-separated paths
    stitch_images(sys.argv[1])