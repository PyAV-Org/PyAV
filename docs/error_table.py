
import av


rows = [(
    #'Tag (Code)',
    'Exception Class',
    'Code/Enum Name',
    'FFmpeg Error Message',
)]

for code, cls in av.error.classes.items():
    
    enum = av.error.ErrorType.get(code)
    
    if not enum:
        continue

    if enum.tag == b'PyAV':
        continue

    rows.append((
        #'{} ({})'.format(enum.tag, code),
        '``av.{}``'.format(cls.__name__),
        '``av.error.{}``'.format(enum.name),
        enum.strerror,
    ))

lens = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]

header = tuple('=' * x for x in lens)
rows.insert(0, header)
rows.insert(2, header)
rows.append(header)

for row in rows:
    print('  '.join('{:{}s}'.format(cell, len_) for cell, len_ in zip(row, lens)))
