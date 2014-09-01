import argparse
import os
import sys
import pprint

from qtproxy import Q
from glproxy import gl

import av

class PlayerGLWidget(Q.GLWidget):

    def initializeGL(self):
        print 'initialize GL'
        gl.clearColor(0, 0, 0, 0)

        gl.enable(gl.TEXTURE_2D)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
        gl.texParameter(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
        
        # gl.texEnv(gl.TEXTURE_ENV, gl.TEXTURE_ENV_MODE, gl.DECAL)
        # self.tex_id = gl.genTextures(1)
        # gl.bindTexture(gl.TEXTURE_2D, self.tex_id)

    def setImage(self, w, h, img):
        gl.texImage2D(gl.TEXTURE_2D, 0, 3, w, h, 0, gl.RGB, gl.UNSIGNED_BYTE, img)

    def resizeGL(self, w, h):
        print 'resize to', w, h
        gl.viewport(0, 0, w, h)
        # gl.matrixMode(gl.PROJECTION)
        # gl.loadIdentity()
        # gl.ortho(0, w, 0, h, -10, 10)
        # gl.matrixMode(gl.MODELVIEW)

    def paintGL(self):
        # print 'paint!'
        gl.clear(gl.COLOR_BUFFER_BIT)
        with gl.begin('polygon'):
            gl.texCoord(0, 0); gl.vertex(-1, -1)
            gl.texCoord(1, 0); gl.vertex( 1, -1)
            gl.texCoord(1, 1); gl.vertex( 1,  1)
            gl.texCoord(0, 1); gl.vertex(-1,  1)



parser = argparse.ArgumentParser()
parser.add_argument('-f', '--format')
parser.add_argument('path')
args = parser.parse_args()


def _iter_images():
    video = av.open(args.path, format=args.format)
    stream = next(s for s in video.streams if s.type == b'video')
    for packet in video.demux(stream):
        for frame in packet.decode():
            rgb, img = frame.to_qimage(960, 540)
            yield rgb, img

image_iter = _iter_images()

app = Q.Application([])

label = Q.Label()
label.setFixedWidth(960)
label.setFixedHeight(540)
label.show()
label.raise_()

glwidget = PlayerGLWidget()
glwidget.show()
glwidget.raise_()


timer = Q.Timer()
timer.setInterval(1000/30)
@timer.timeout.connect
def on_timeout(*args):
    rgb_frame, qimage = next(image_iter)
    label.setPixmap(Q.Pixmap.fromImage(qimage))
    glwidget.setImage(960, 540, rgb_frame.planes[0].to_bytes()) # memoryview(rgb_frame.planes[0]))
    glwidget.updateGL()
timer.start()

app.exec_()
