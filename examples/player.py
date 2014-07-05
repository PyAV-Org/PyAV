import argparse
import os
import sys
import pprint

from PyQt4 import QtCore, QtGui

import av


parser = argparse.ArgumentParser()
parser.add_argument('video')
args = parser.parse_args()


def _iter_images():
    video = av.open(args.video)
    stream = next(s for s in video.streams if s.type == b'video')
    for packet in video.demux(stream):
        for frame in packet.decode():
            rgb, img = frame.to_qimage(960, 540)
            yield img

image_iter = _iter_images()

app = QtGui.QApplication([])

label = QtGui.QLabel()
label.setFixedWidth(960)
label.setFixedHeight(540)
label.show()
label.raise_()


timer = QtCore.QTimer()
timer.setInterval(1000/30)
@timer.timeout.connect
def on_timeout(*args):
    label.setPixmap(QtGui.QPixmap.fromImage(next(image_iter)))
timer.start()

app.exec_()
