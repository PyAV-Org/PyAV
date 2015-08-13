from av.filter.graph import Graph

g = Graph()
print g.dump()

f = g.pull()

print f

f = f.reformat(format='rgb24')

print f

img = f.to_image()

print img

img.save('graph.png')
