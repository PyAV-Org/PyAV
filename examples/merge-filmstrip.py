import os
import sys

from PIL import Image


final_width = 10 * 300 * 2

for src_dir in sys.argv[1:]:

	out_path = src_dir + '.jpg'
	if os.path.exists(out_path):
		continue

	if not os.path.exists(src_dir):
		print 'Missing input:', src_dir
		continue

	if not os.path.isdir(src_dir):
		continue
	
	names = sorted(os.listdir(src_dir))
	names = [x for x in names if not x.startswith('.')]
	names = [x for x in names if x != 'done']
	
	if not names:
		print 'No images in', src_dir
		continue

	images = [Image.open(os.path.join(src_dir, name)) for name in names]
	width = sum(image.size[0] for image in images)

	merged = Image.new("RGBA", (width, images[0].size[1]))
	x = 0
	for i, image in enumerate(images):
		print '%d of %d' % (i + 1, len(images))
		merged.paste(image, (x, 0))
		x += image.size[0]

	print 'resizing'
	merged = merged.resize((final_width, merged.size[1]), Image.ANTIALIAS)

	print 'saving'
	merged.save(out_path, qualty=90)


