Examples
========

Writing a movie from numpy

::

    duration = 10  # Seconds
    frames_per_second = 24
    total_frames = duration * frames_per_second

    container = av.open('test.mp4', mode='w')
    container.metadata['title'] = 'Some Title'
    container.metadata['key'] = 'value'

    stream = container.add_stream('mpeg4', rate=frames_per_second)
    stream.width = 480
    stream.height = 320
    stream.pix_fmt = 'yuv420p'

    for frame_i in range(total_frames):

        img = np.empty((480, 320, 3))
        img[:, :, 0] = 0.5 + 0.5 * np.sin(frame_i / duration * 2 * np.pi)
        img[:, :, 1] = 0.5 + 0.5 * np.sin(frame_i / duration * 2 * np.pi + 2 / 3 * np.pi)
        img[:, :, 2] = 0.5 + 0.5 * np.sin(frame_i / duration * 2 * np.pi + 4 / 3 * np.pi)
        
        img = np.round(255 * img).astype(np.uint8)
        img[img < 0] = 0
        img[img > 255] = 255

        frame = av.VideoFrame.from_ndarray(img, format='rgb24')
        packet = stream.encode(frame)
        if packet is not None:
            container.mux(packet)

    # Finish encoding the stream
    while True:
        packet = stream.encode()
        if packet is None:
            break
        container.mux(packet)

    # Close the file
    container.close()
