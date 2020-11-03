#!/usr/bin/env python3
import yaml
import sys
import json


def clean_dict(d):
    for key, value in list(d.items()):
        if value is None or (isinstance(value, dict) and len(value) == 0):
            del d[key]
        elif isinstance(value, dict):
            clean_dict(value)
    return d  # For convenience


def process_file(inputfile: str):
    if inputfile.endswith('.yaml'):
        with open(inputfile) as yaml_file:
            map = yaml.safe_load(yaml_file)
            map_as_str = str(clean_dict(map))
            print(map_as_str.replace('\'', '"'))
    else:
        raise Exception("File should have a suffix of .yaml")


def main(argv):
    inputfile = ''
    try:
        inputfile = argv[0]
    except:
        print('convert_to_python_map <inputfile>')
        sys.exit(2)
    process_file(inputfile)


if __name__ == '__main__':
    main(sys.argv[1:])
