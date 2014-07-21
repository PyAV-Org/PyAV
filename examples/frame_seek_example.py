"""
Note this example only really works accurately on constant frame rate media. 
"""
from PyQt4 import QtGui
from PyQt4 import QtCore
from PyQt4.QtCore import Qt

import sys
import av

def next_frame(container, stream):
    for packet in container.demux(stream):
        #print "*", packet.pts, packet.dts, packet
        for frame in packet.decode():
            yield frame

AV_TIME_BASE = 1000000

def pts_to_frame(pts, time_base, frame_rate, start_time):
    return int((pts - start_time )* time_base * frame_rate)

def get_frame_rate(stream):
    
    if stream.average_rate.denominator and stream.average_rate.numerator:
        return float(stream.average_rate)
    if stream.time_base.denominator and stream.time_base.numerator:
        return 1.0/float(stream.time_base)
    else:
        raise ValueError("Unable to determine FPS")
    
def get_frame_count(f, stream):
    
    if stream.frames:
        return stream.frames
    elif stream.duration:
        return pts_to_frame(stream.duration, float(stream.time_base), get_frame_rate(stream), 0)
    elif f.duration:
        return pts_to_frame(f.duration, 1/float(AV_TIME_BASE), get_frame_rate(stream), 0)
        
    else:
        raise ValueError("Unable to determine number for frames")

class FrameGrabber(QtCore.QObject):
    
    frame_ready = QtCore.pyqtSignal(object, object)
    update_frame_range = QtCore.pyqtSignal(object)
    
    def __init__(self, parent =None):
        super(FrameGrabber, self).__init__(parent)
        self.file = None
        self.stream = None
        self.frame = None
        self.active_frame = None
        
    @QtCore.pyqtSlot(object)
    def request_frame(self, target_frame):

        if target_frame != self.active_frame:
            return
        print 'seeking to', target_frame
        
        seek_frame = target_frame

        rate = get_frame_rate(self.stream)
        
        time_base = float(self.stream.time_base)
        
        frame = None
        reseek = 500
        
        while reseek >= 0:
            
            # convert seek_frame to pts
            target_sec = seek_frame * 1/rate
            target_pts = int(target_sec / time_base) + self.stream.start_time
            
            self.stream.seek(int(target_pts))
            
            frame_index = None
            
            for i,frame in enumerate(next_frame(self.file, self.stream)):
                
                # optimization if the time slider has changed, the requested frame no longer valid
                if target_frame != self.active_frame:
                    return
                
                # First we need to determine what frame we landed one
                
                if frame_index is None:
                    # convert frame pts into a frame number
                    # the first frame returned after a seek "should" have a valid pts
                    pts = frame.pts
                    if not pts is None:
                        frame_index = pts_to_frame(pts, time_base, rate, self.stream.start_time)
                else:
                    frame_index += 1
                    
                print "   ", i, frame_index, "at:", frame.pts,frame.dts,"target:", target_pts
                
                # Now that we might know what frame we are at check if its the target frame
               
                if frame_index is None:
                    continue
            
                elif frame_index >= target_frame:
                    break
                
            # Check if we over seeked, if we over seekd we need to seek to a earlier time
            # but still looking for the target frame
            if frame_index != target_frame:
                
                seek_frame -= 1
                reseek -= 1
                print "over seeked, backtracking.. seeking: %i target: %i retry: %i" % ( seek_frame, target_frame, reseek)

            else:
                break
        
        if reseek < 0:
            raise ValueError("seeking failed %i" % frame_index)
            
        # frame at this point should be the correct frame
        
        if frame:
            
            rgba = frame.reformat(frame.width, frame.height, "rgb24", 'itu709')
            
            # could use the buffer interface here instead, some versions of PyQt don't support it for some reason
            # need to track down which version they added support for it
            self.frame = bytearray(rgba.planes[0])
            img = QtGui.QImage(self.frame, rgba.width, rgba.height, QtGui.QImage.Format_RGB888)
            
            #img = QtGui.QImage(rgba.planes[0], rgba.width, rgba.height, QtGui.QImage.Format_RGB888)

            pixmap = QtGui.QPixmap.fromImage(img)
            self.frame_ready.emit(pixmap, frame_index)
        else:
            raise ValueError("seeking failed %i" % target_frame)

    def set_file(self, path):
        self.file = av.open(path)
        self.stream = next(s for s in self.file.streams if s.type == b'video')
        
        self.update_frame_range.emit(get_frame_count(self.file, self.stream))
        
class DisplayWidget(QtGui.QLabel):
    def __init__(self, parent=None):
        super(DisplayWidget, self).__init__(parent)
        #self.setScaledContents(True)
        self.setMinimumSize(1920/10, 1080/10)
        
        size_policy = QtGui.QSizePolicy(QtGui.QSizePolicy.Preferred, QtGui.QSizePolicy.Preferred)
        size_policy.setHeightForWidth(True)
        
        self.setSizePolicy(size_policy)
        
        self.setAlignment(Qt.AlignHCenter| Qt.AlignBottom)

        self.pixmap = None
        self.setMargin(10)
        
    def heightForWidth(self, width):
        return width * 9 / 16.0
    
    @QtCore.pyqtSlot(object, object)
    def setPixmap(self, pixmap, index):
        #if index == self.current_index:
        self.pixmap = pixmap
        super(DisplayWidget, self).setPixmap(self.pixmap.scaled(self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
    
    def sizeHint(self):
        width = self.width()
        return QtCore.QSize(width, self.heightForWidth(width))
    
    def resizeEvent(self, event):
        if self.pixmap:
            super(DisplayWidget, self).setPixmap(self.pixmap.scaled(self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
        
    def sizeHint(self):
        return QtCore.QSize(1920/2.5,1080/2.5)
        

class VideoPlayerWidget(QtGui.QWidget):
    
    request_frame = QtCore.pyqtSignal(object)
    
    def __init__(self, parent=None):
        super(VideoPlayerWidget, self).__init__(parent)
        self.display = DisplayWidget()
        self.timeline = QtGui.QScrollBar(Qt.Horizontal)
        self.frame_grabber = FrameGrabber()
        
        self.frame_control = QtGui.QSpinBox()
        self.frame_control.setFixedWidth(100)

        self.timeline.valueChanged.connect(self.frame_changed)
        self.frame_control.valueChanged.connect(self.frame_changed)
        self.request_frame.connect(self.frame_grabber.request_frame)

        self.frame_grabber.frame_ready.connect(self.display.setPixmap)
        self.frame_grabber.update_frame_range.connect(self.set_frame_range)
        
        self.frame_grabber_thread = QtCore.QThread()
        
        self.frame_grabber.moveToThread(self.frame_grabber_thread)
        self.frame_grabber_thread.start()
        
        control_layout = QtGui.QHBoxLayout()
        control_layout.addWidget(self.frame_control)
        control_layout.addWidget(self.timeline)
        
        layout = QtGui.QVBoxLayout()
        layout.addWidget(self.display)
        layout.addLayout(control_layout)
        self.setLayout(layout)
        self.setAcceptDrops(True)
        
    def set_file(self, path):
        self.frame_grabber.set_file(path)
        self.frame_changed(0)
        
    @QtCore.pyqtSlot(object)
    def set_frame_range(self, maximum):
        print "frame range =", maximum
        self.timeline.setMaximum(maximum)
        self.frame_control.setMaximum(maximum)
    
    def frame_changed(self, value):
        self.timeline.blockSignals(True)
        self.frame_control.blockSignals(True)
        
        self.timeline.setValue(value)
        self.frame_control.setValue(value)
        
        self.timeline.blockSignals(False)
        self.frame_control.blockSignals(False)
        
        #self.display.current_index = value
        self.frame_grabber.active_frame = value
        
        self.request_frame.emit(value)
        
    def keyPressEvent(self, event):
        if event.key() in (Qt.Key_Right, Qt.Key_Left):
            direction = 1
            if event.key() == Qt.Key_Left:
                direction = -1
                
            if event.modifiers() == Qt.ShiftModifier:
                print 'shift'
                direction *= 10
                
            self.timeline.setValue(self.timeline.value() + direction)
                
        else:
            super(VideoPlayerWidget,self).keyPressEvent(event)
            
    def mousePressEvent(self, event):
        # clear focus of spinbox
        focused_widget = QtGui.QApplication.focusWidget()
        if focused_widget:
            focused_widget.clearFocus()
            
        super(VideoPlayerWidget,self).mousePressEvent(event)
        
    def dragEnterEvent(self, event):
        event.accept()
        
    def dropEvent(self, event):
        
        mime = event.mimeData()
        event.accept()
        
        
        if mime.hasUrls():
            path = str(mime.urls()[0].path())
            self.set_file(path)
        

if __name__ == "__main__":
    app = QtGui.QApplication(sys.argv)
    window = VideoPlayerWidget()
    test_file = sys.argv[1]
    window.set_file(test_file)                      
    window.show()
    sys.exit(app.exec_()) 

