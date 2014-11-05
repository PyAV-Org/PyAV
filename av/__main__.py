import argparse


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('--codecs', action='store_true')
    args = parser.parse_args()

    # ---

    if args.codecs:
        from av.codec import dump_codecs
        dump_codecs()


if __name__ == '__main__':
    main()
