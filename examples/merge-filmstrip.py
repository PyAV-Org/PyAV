import os
import sys

import Image


final_width = 10 * 300 * 2

for src_dir in sys.argv[1:]:

	names = sorted(os.listdir(src_dir))
	names = [x for x in names if not x.startswith('.')]
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
	merged.save(src_dir + '.jpg', qualty=90)


