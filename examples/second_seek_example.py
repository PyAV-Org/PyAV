"""
Note this example only really works accurately on constant frame rate media. 
"""
from PyQt4 import QtGui
from PyQt4 import QtCore
from PyQt4.QtCore import Qt

import sys
import av


AV_TIME_BASE = 1000000

def pts_to_frame(pts, time_base, frame_rate, start_time):
    return int(pts * time_base * frame_rate) - int(start_time * time_base * frame_rate)

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
    update_frame_range = QtCore.pyqtSignal(object, object)
    
    def __init__(self, parent =None):
        super(FrameGrabber, self).__init__(parent)
        self.file = None
        self.stream = None
        self.frame = None
        self.active_time = None
        self.start_time = 0
        self.pts_seen = False
        self.nb_frames = None
        
        self.rate = None
        self.time_base = None
        
        self.pts_map = {}
        
    def next_frame(self):
        
        frame_index = None
        
        rate = self.rate
        time_base = self.time_base
        
        self.pts_seen = False
        
        for packet in self.file.demux(self.stream):
            #print "    pkt", packet.pts, packet.dts, packet
            if packet.pts:
                self.pts_seen = True
            
            for frame in packet.decode():
                
                if frame_index is None:
                    
                    if self.pts_seen:
                        pts = frame.pts
                    else:
                        pts = frame.dts
                    
                    if not pts is None:
                        frame_index = pts_to_frame(pts, time_base, rate, self.start_time)
                        
                elif not frame_index is None:
                    frame_index += 1
                
                if not frame.dts in self.pts_map:
                    secs  = None
                    
                    if not pts is None:
                        secs = pts * time_base
                    
                    self.pts_map[frame.dts] = secs
                    
                
                #if frame.pts == None:
                    
                
                
                yield frame_index, frame
                
                
    
    @QtCore.pyqtSlot(object)
    def request_time(self, second):
        
        frame = self.get_frame(second)
        if not frame:
            return
        
        rgba = frame.reformat(frame.width, frame.height, "rgb24", 'itu709')
        #print rgba.to_image().save("test.png")
        # could use the buffer interface here instead, some versions of PyQt don't support it for some reason
        # need to track down which version they added support for it
        self.frame = bytearray(rgba.planes[0])
        bytesPerPixel  =3 
        img = QtGui.QImage(self.frame, rgba.width, rgba.height, rgba.width * bytesPerPixel, QtGui.QImage.Format_RGB888)
        
        #img = QtGui.QImage(rgba.planes[0], rgba.width, rgba.height, QtGui.QImage.Format_RGB888)

        #pixmap = QtGui.QPixmap.fromImage(img)
        self.frame_ready.emit(img, second)
        
    def get_frame(self, target_sec):

        if target_sec != self.active_time:
            return
        print 'seeking to', target_sec
        
        rate = self.rate
        time_base = self.time_base
        
        target_pts = int(target_sec / time_base) + self.start_time
        seek_pts = target_pts
        
        
        self.stream.seek(seek_pts)
        
        #frame_cache = []
        
        last_frame= None
        
        for i, (frame_index, frame) in enumerate(self.next_frame()):
            
            
            if target_sec != self.active_time:
                return
            
            pts =frame.dts
            if self.pts_seen:
                pts = frame.pts
            
            if pts > target_pts:
                break
            
            print frame.pts, seek_pts
            last_frame = frame
            
        if last_frame:
            
            return last_frame
        
        
    def get_frame_old(self, target_frame):

        if target_frame != self.active_frame:
            return
        print 'seeking to', target_frame
        
        seek_frame = target_frame

        rate = self.rate
        time_base = self.time_base
        
        frame = None
        reseek = 250
        
        original_target_frame_pts = None
        
        while reseek >= 0:
            
            # convert seek_frame to pts
            target_sec = seek_frame * 1/rate
            target_pts = int(target_sec / time_base) + self.start_time
            
            if original_target_frame_pts is None:
                original_target_frame_pts = target_pts
            
            self.stream.seek(int(target_pts))
            
            frame_index = None
            
            frame_cache = []
            
            for i, (frame_index, frame) in enumerate(self.next_frame()):
                
                # optimization if the time slider has changed, the requested frame no longer valid
                if target_frame != self.active_frame:
                    return
                
                print "   ", i, "at frame", frame_index, "at ts:", frame.pts,frame.dts,"target:", target_pts, 'orig', original_target_frame_pts

                if frame_index is None:
                    pass
                
                elif frame_index >= target_frame:
                    break
                
                frame_cache.append(frame)
                
            # Check if we over seeked, if we over seekd we need to seek to a earlier time
            # but still looking for the target frame
            if frame_index != target_frame:
                
                if frame_index is None:
                    over_seek = '?'
                else:
                    over_seek = frame_index - target_frame
                    if frame_index > target_frame:
                        
                        print over_seek, frame_cache
                        if over_seek <= len(frame_cache):
                            print "over seeked by %i, using cache" % over_seek
                            frame = frame_cache[-over_seek]
                            break

                    
                seek_frame -= 1
                reseek -= 1
                print "over seeked by %s, backtracking.. seeking: %i target: %i retry: %i" % (str(over_seek),  seek_frame, target_frame, reseek)

            else:
                break
        
        if reseek < 0:
            raise ValueError("seeking failed %i" % frame_index)
            
        # frame at this point should be the correct frame
        
        if frame:
            
            return frame
        
        else:
            raise ValueError("seeking failed %i" % target_frame)
        
    def get_frame_count(self):
        
        frame_count = None
        
        if self.stream.frames:
            frame_count = self.stream.frames
        elif self.stream.duration:
            frame_count =  pts_to_frame(self.stream.duration, float(self.stream.time_base), get_frame_rate(self.stream), 0)
        elif self.file.duration:
            frame_count = pts_to_frame(self.file.duration, 1/float(AV_TIME_BASE), get_frame_rate(self.stream), 0)
        else:
            raise ValueError("Unable to determine number for frames")
        
        seek_frame = frame_count
        
        retry = 100
        
        while retry:
            target_sec = seek_frame * 1/ self.rate
            target_pts = int(target_sec / self.time_base) + self.start_time
            
            self.stream.seek(int(target_pts))
            
            frame_index = None
            
            for frame_index, frame in self.next_frame():
                print frame_index, frame
                continue
            
            if not frame_index is None:
                break
            else:
                seek_frame -= 1 
                retry -= 1
                
        
        print "frame count seeked", frame_index, "container frame count", frame_count
        
        return frame_index or frame_count
    
    @QtCore.pyqtSlot(object)
    def set_file(self, path):
        self.file = av.open(path)
        self.stream = next(s for s in self.file.streams if s.type == b'video')
        self.rate = get_frame_rate(self.stream)
        self.time_base = float(self.stream.time_base)
        

        index, first_frame = next(self.next_frame())
        self.stream.seek(self.stream.start_time)

        # find the pts of the first frame
        index, first_frame = next(self.next_frame())

        if self.pts_seen:
            pts = first_frame.pts
        else:
            pts = first_frame.dts
 
        self.start_time = pts or first_frame.dts
            
        print "First pts", pts, self.stream.start_time, first_frame

        #self.nb_frames = get_frame_count(self.file, self.stream)
        self.nb_frames = self.get_frame_count()
        
        dur = None
        
        if self.stream.duration:
            dur = self.stream.duration * self.time_base
        else:
            dur = self.file.duration * 1.0 / float(AV_TIME_BASE)
        
        self.update_frame_range.emit(dur, self.rate)
        
        
        
        
        
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
    def setPixmap(self, img, index):
        #if index == self.current_index:
        self.pixmap = QtGui.QPixmap.fromImage(img)
        
        #super(DisplayWidget, self).setPixmap(self.pixmap)
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
    
    request_time = QtCore.pyqtSignal(object)
    
    load_file = QtCore.pyqtSignal(object)
    
    def __init__(self, parent=None):
        super(VideoPlayerWidget, self).__init__(parent)
        
        self.rate = None
        
        self.display = DisplayWidget()
        self.timeline = QtGui.QScrollBar(Qt.Horizontal)
        self.timeline_base = 100000
        
        self.frame_grabber = FrameGrabber()
        
        self.frame_control = QtGui.QDoubleSpinBox()
        self.frame_control.setFixedWidth(100)

        self.timeline.valueChanged.connect(self.slider_changed)
        self.frame_control.valueChanged.connect(self.frame_changed)
        
        self.request_time.connect(self.frame_grabber.request_time)
        self.load_file.connect(self.frame_grabber.set_file)

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
        #self.frame_grabber.set_file(path)
        self.load_file.emit(path)
        self.frame_changed(0)
        
    @QtCore.pyqtSlot(object, object)
    def set_frame_range(self, maximum, rate):
        print "frame range =", maximum, rate, int(maximum * self.timeline_base)
        
        self.timeline.setMaximum( int(maximum * self.timeline_base))
        
        self.frame_control.setMaximum(maximum)
        self.frame_control.setSingleStep(1/rate)
        #self.timeline.setSingleStep( int(AV_TIME_BASE * 1/rate))
        self.rate = rate
        
    def slider_changed(self, value):
        print '..', value
        self.frame_changed(value * 1.0 / float(self.timeline_base))
    
    def frame_changed(self, value):
        self.timeline.blockSignals(True)
        self.frame_control.blockSignals(True)
        
        self.timeline.setValue(int(value * self.timeline_base))
        self.frame_control.setValue( value)
        
        self.timeline.blockSignals(False)
        self.frame_control.blockSignals(False)
        
        #self.display.current_index = value
        self.frame_grabber.active_time = value
        
        self.request_time.emit(value)
        
    def keyPressEvent(self, event):
        if event.key() in (Qt.Key_Right, Qt.Key_Left):
            direction = 1
            if event.key() == Qt.Key_Left:
                direction = -1
                
            if event.modifiers() == Qt.ShiftModifier:
                print 'shift'
                direction *= 10
            
            direction = direction * 1/self.rate
                
            self.frame_changed(self.frame_control.value() + direction)
                
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
    def closeEvent(self, event):
        
        self.frame_grabber.active_time = -1
        self.frame_grabber_thread.quit()
        self.frame_grabber_thread.wait()
        
        for key,value in sorted(self.frame_grabber.pts_map.items()):
            print key, '=', value
        
        event.accept()
        

if __name__ == "__main__":
    app = QtGui.QApplication(sys.argv)
    window = VideoPlayerWidget()
    test_file = sys.argv[1]
    window.set_file(test_file)                      
    window.show()
    sys.exit(app.exec_()) 

