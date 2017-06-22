import av

def main():
    inp = av.open('piano2.wav', 'r')
    out = av.open('piano2.mp3', 'w')
    ostream = out.add_stream("mp3")

    for frame in inp.decode(audio=0):
        frame.pts = None

        for p in ostream.encode(frame):
            out.mux(p)

    for p in ostream.encode(None):
        out.mux(p)

    out.close()


def main():
    inp = av.open('piano2.wav', 'r')
    out = av.open('piano2.mp3', 'w')
    ostream = out.add_stream("mp3")

    for frame in inp.decode(audio=0):
        frame.pts = None
        out_packets = [ostream.encode(frame)]

        while out_packets[-1]:
            out_packets.append(ostream.encode(None))

        for p in out_packets:
            if p:
                out.mux(p)

    while True:
        out_packet = ostream.encode(None)
        if out_packet:
            out.mux(out_packet)
        else:
            break
    out.close()



if __name__ == '__main__':
    main()