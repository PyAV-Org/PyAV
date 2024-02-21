import argparse


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--codecs", action="store_true")
    parser.add_argument("--version", action="store_true")
    args = parser.parse_args()

    if args.version:
        import av
        import av._core

        print(f"PyAV v{av.__version__}")

        by_config = {}
        for libname, config in sorted(av._core.library_meta.items()):
            version = config["version"]
            if version[0] >= 0:
                by_config.setdefault(
                    (config["configuration"], config["license"]), []
                ).append((libname, config))

        for (config, license), libs in sorted(by_config.items()):
            print("library configuration:", config)
            print("library license:", license)
            for libname, config in libs:
                version = config["version"]
                print(f"{libname:<13} {version[0]:3d}.{version[1]:3d}.{version[2]:3d}")

    if args.codecs:
        from av.codec.codec import dump_codecs

        dump_codecs()


if __name__ == "__main__":
    main()
