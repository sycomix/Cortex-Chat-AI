import argparse
import csv, sys

parser = argparse.ArgumentParser(description='Prepare chat data to be processed by torch-rnn')
parser.add_argument('ChatFile', metavar='chatfile', type=str, help='The chat csv file to process')
args = parser.parse_args()

names = []

with open(args.ChatFile, 'r', encoding='utf-8') as csv_file:
    with open('chat.txt', 'a', encoding='utf-8') as out_file:
        csv_reader = csv.reader(csv_file, delimiter=';')
        for line_count, row in enumerate(csv_reader):

            if line_count == 0:
                print(f'Columns are {", ".join(row)}')
            else:
                name = row[0][:-5]
                msg = row[2]

                if name not in names:
                    names.append(name)

                out_file.write(f'[{names.index(name)}]: {msg}' + '\n')

                if line_count % 1000 == 0:
                    sys.stdout.write('\r{0} lines processed'.format(line_count))
                    sys.stdout.flush()

print('\nWriting {0} indices to name index file'.format(len(names)))

with open('players.txt', 'a', encoding='utf-8') as namefile:
    for n in names:
        idx = names.index(n)
        namefile.write(f"{idx} : {n}" + '\n')