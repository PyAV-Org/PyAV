import sys
import time

from PyQt4 import QtCore, QtGui
Qt = QtCore.Qt

import Image

import av.tutorial


app = QtGui.QApplication([])
label = QtGui.QLabel()
label.setFixedWidth(640)
label.setFixedHeight(360)

label.show()

frames = av.tutorial.iter_frames(sys.argv)
timer = QtCore.QTimer()
timer.setInterval(1000/24.0)

start = 0
count = 0
@timer.timeout.connect
def go():
    global start, count
    start = start or time.time()
    count += 1
    try:
        frame_buffer = next(frames)
    except:
        timer.stop()
        app.exit(0)
        raise
    
    img = QtGui.QImage(frame_buffer, 640, 360, QtGui.QImage.Format_ARGB32)
    pixmap = QtGui.QPixmap(img)
    label.setPixmap(pixmap)

timer.start()
app.exec_()
print float(count) / (time.time() - start)

