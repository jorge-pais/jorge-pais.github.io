import os
import re
import shutil
import yaml
from datetime import datetime

OBSIDIAN_VAULT_PATH = ""
JEKYLL_ROOT = ""
NOTE_NAME = "Sleep from scratch - Introduction to amd64 baremetal programming.md" 

def convert_to_jekyll():
    note_path = os.path.join(OBSIDIAN_VAULT_PATH, NOTE_NAME)
    if not os.path.exists(note_path):
        print(f"Error: {note_path} not found.")
        return

    with open(note_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # extract title
    content_body = ""
    extracted_title = "Untitled Post"
    h1_found = False

    for line in lines:
        if not h1_found and line.startswith("# "):
            extracted_title = line.replace("# ", "").strip()
            h1_found = True
            continue # Skip adding the actual # H1 to the body
        content_body += line

    jekyll_header = f"""---
layout: post
title: {extracted_title}
date: 2021-12-31
tags: 
    - Music Electronics
categories:
    - projects

permalink_name: /projects
---

"""

    date_str = "2021-12-31" 
    folder_slug = f"{date_str}-{NOTE_NAME.replace('.md', '')}"
    jekyll_img_dir = os.path.join(JEKYLL_ROOT, "img", folder_slug)
    
    if not os.path.exists(jekyll_img_dir):
        os.makedirs(jekyll_img_dir)

    # image replacement
    obsidian_pattern = re.compile(r'!\[\[(.*?)\]\]')

    def processor(match):
        img_filename = match.group(1).split('|')[0]
        
        # check root and common attachment folders
        src_locations = [
            os.path.join(OBSIDIAN_VAULT_PATH, img_filename),
            os.path.join(OBSIDIAN_VAULT_PATH, "attachments", img_filename),
            os.path.join(OBSIDIAN_VAULT_PATH, "Attachments", img_filename)
        ]
        
        src_img = next((loc for loc in src_locations if os.path.exists(loc)), None)

        if src_img:
            shutil.copy(src_img, os.path.join(jekyll_img_dir, img_filename))

            return f'![{img_filename}](/img/{folder_slug}/{img_filename})'
        
        return match.group(0)

    # 5. Assemble and Save
    final_content = jekyll_header + obsidian_pattern.sub(processor, content_body)
    
    output_filename = f"{date_str}-{NOTE_NAME}"
    output_path = os.path.join(JEKYLL_ROOT, "_posts", output_filename)

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(final_content)

    print(f"Post generated: {output_path}")

if __name__ == "__main__":
    convert_to_jekyll()
