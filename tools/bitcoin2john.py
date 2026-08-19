#!/usr/bin/env python

# bitcoin2john.py with Pure-Python Berkeley DB Fallback for Python 3.13 / Windows
# Extracts master key hash for Hashcat mode 11300 and John the Ripper

import binascii
import logging
import os
import struct
import sys
import sqlite3

bsddb_db = None

def do_import_bsddb():
    global bsddb_db
    if bsddb_db is not None:
        return True
    try:
        import bsddb.db as bdb
        bsddb_db = bdb
        return True
    except Exception:
        try:
            import bsddb3.db as bdb
            bsddb_db = bdb
            return True
        except Exception:
            return False

json_db = {}

def hexstr(bytestr):
    return binascii.hexlify(bytestr).decode('ascii')

class SerializationError(Exception):
    """Error in serialization"""

class BCDataStream(object):
    def __init__(self):
        self.input = None
        self.read_cursor = 0

    def clear(self):
        self.input = None
        self.read_cursor = 0

    def write(self, bytes_data):
        if self.input is None:
            self.input = bytes_data
        else:
            self.input += bytes_data

    def map_file(self, file, start):
        self.input = mmap.mmap(file.fileno(), 0, access=mmap.ACCESS_READ)
        self.read_cursor = start

    def seek_file(self, position):
        self.read_cursor = position

    def close_file(self):
        self.input.close()

    def read_string(self):
        # Strings are serialized with length as compact_size
        length = self.read_compact_size()
        return self.read_bytes(length).decode('ascii', errors='ignore')

    def read_bytes(self, length):
        try:
            result = self.input[self.read_cursor:self.read_cursor+length]
            self.read_cursor += length
            return result
        except IndexError:
            raise SerializationError("attempt to read past end of buffer")

    def read_boolean(self): return self.read_bytes(1)[0] != 0
    def read_int16(self): return self._read_num('<h')
    def read_uint16(self): return self._read_num('<H')
    def read_int32(self): return self._read_num('<i')
    def read_uint32(self): return self._read_num('<I')
    def read_int64(self): return self._read_num('<q')
    def read_uint64(self): return self._read_num('<Q')

    def read_compact_size(self):
        size = self.input[self.read_cursor]
        self.read_cursor += 1
        if size == 253:
            return self.read_uint16()
        if size == 254:
            return self.read_uint32()
        if size == 255:
            return self.read_uint64()
        return size

    def _read_num(self, format):
        (i,) = struct.unpack_from(format, self.input, self.read_cursor)
        self.read_cursor += struct.calcsize(format)
        return i

def read_wallet_purepython(json_db, wallet_filename):
    wallet_filename = os.path.abspath(wallet_filename)
    mkey_bytes = None

    def align_32bits(i):
        m = i % 4
        return i if m == 0 else i + 4 - m

    if os.path.exists(wallet_filename):
        with open(wallet_filename, "rb") as wallet_file:
            wallet_file.seek(12)
            magic = wallet_file.read(8)
            # Berkeley DB magic bytes: Btree v9
            if magic == b"\x62\x31\x05\x00\x09\x00\x00\x00" or magic == b"\x00\x05\x31\x62\x00\x00\x00\x09":
                wallet_file.seek(20)
                raw_page_size = wallet_file.read(4)
                if len(raw_page_size) == 4:
                    page_size = struct.unpack(b"<I", raw_page_size)[0]
                    wallet_file_size = os.path.getsize(wallet_filename)
                    if page_size > 0:
                        for page_base in range(page_size, wallet_file_size, page_size):
                            wallet_file.seek(page_base + 20)
                            page_hdr = wallet_file.read(6)
                            if len(page_hdr) < 6:
                                continue
                            (item_count, first_item_pos, btree_level, page_type) = struct.unpack(b"< H H B B", page_hdr)
                            if page_type != 5 or btree_level != 1:
                                continue
                            pos = align_32bits(page_base + first_item_pos)
                            wallet_file.seek(pos)
                            for i in range(item_count):
                                raw_len_type = wallet_file.read(3)
                                if len(raw_len_type) < 3:
                                    break
                                (item_len, item_type) = struct.unpack(b"< H B", raw_len_type)
                                if item_type & ~0x80 == 1:
                                    if item_type == 1:
                                        if i % 2 == 0:
                                            value_pos = pos + 3
                                            value_len = item_len
                                        elif item_len == 9 and wallet_file.read(item_len) == b"\x04mkey\x01\x00\x00\x00":
                                            wallet_file.seek(value_pos)
                                            mkey_bytes = wallet_file.read(value_len)
                                            break
                                    pos = align_32bits(pos + 3 + item_len)
                                else:
                                    pos += 12
                                if i + 1 < item_count:
                                    if pos >= page_base + page_size:
                                        break
                                    wallet_file.seek(pos)
                            else:
                                continue
                            break

    # If not found yet, check SQLite format (modern Bitcoin/Dogecoin Core)
    if not mkey_bytes:
        try:
            conn = sqlite3.connect(wallet_filename)
            for key, value in conn.execute('SELECT * FROM main'):
                if b"\x04mkey\x01\x00\x00\x00" in key:
                    mkey_bytes = value
                    break
            conn.close()
        except Exception:
            pass

    if not mkey_bytes:
        return -1

    try:
        vds = BCDataStream()
        vds.write(mkey_bytes)
        json_db['mkey'] = {}
        json_db['mkey']['encrypted_key'] = hexstr(vds.read_bytes(vds.read_compact_size()))
        json_db['mkey']['salt'] = hexstr(vds.read_bytes(vds.read_compact_size()))
        json_db['mkey']['nDerivationMethod'] = vds.read_uint32()
        json_db['mkey']['nDerivationIterations'] = vds.read_uint32()
        return {'crypted': True}
    except Exception as e:
        sys.stderr.write("Failed to unpack mkey: %s\n" % e)
        return -1

def open_wallet(walletfile):
    db_env = bsddb_db.DBEnv()
    db_env.open(os.path.dirname(os.path.abspath(walletfile)), bsddb_db.DB_CREATE | bsddb_db.DB_INIT_MPOOL)
    db = bsddb_db.DB(db_env)
    db.open(walletfile, "main", bsddb_db.DB_BTREE, bsddb_db.DB_RDONLY)
    return db

def parse_wallet(db, item_callback):
    kds = BCDataStream()
    vds = BCDataStream()
    for (key, value) in db.items():
        kds.clear(); kds.write(key)
        vds.clear(); vds.write(value)
        type = kds.read_string()
        d = {"__key__": key, "__value__": value, "__type__": type}
        try:
            if type == "mkey":
                d['encrypted_key'] = vds.read_bytes(vds.read_compact_size())
                d['salt'] = vds.read_bytes(vds.read_compact_size())
                d['nDerivationMethod'] = vds.read_uint32()
                d['nDerivationIterations'] = vds.read_uint32()
            item_callback(type, d)
        except Exception:
            pass

def read_wallet(json_db, walletfile):
    if do_import_bsddb():
        try:
            db = open_wallet(walletfile)
            json_db['mkey'] = {}
            def item_callback(type, d):
                if type == "mkey":
                    json_db['mkey']['encrypted_key'] = hexstr(d['encrypted_key'])
                    json_db['mkey']['salt'] = hexstr(d['salt'])
                    json_db['mkey']['nDerivationMethod'] = d['nDerivationMethod']
                    json_db['mkey']['nDerivationIterations'] = d['nDerivationIterations']
            parse_wallet(db, item_callback)
            db.close()
            if 'salt' in json_db['mkey']:
                return {'crypted': True}
        except Exception:
            pass

    # Fallback to pure-Python Berkeley DB scanner
    return read_wallet_purepython(json_db, walletfile)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.stderr.write("Usage: %s [Bitcoin/Dogecoin Core wallet (.dat) files]\n" % sys.argv[0])
        sys.exit(1)

    for i in range(1, len(sys.argv)):
        filename = sys.argv[i]
        res = read_wallet(json_db, filename)
        if res == -1 or 'mkey' not in json_db or 'salt' not in json_db['mkey']:
            sys.stderr.write("%s: this wallet is not encrypted or master key was not found\n" % filename)
            continue

        cry_master = binascii.unhexlify(json_db['mkey']['encrypted_key'])
        cry_salt = binascii.unhexlify(json_db['mkey']['salt'])
        cry_rounds = json_db['mkey']['nDerivationIterations']
        cry_method = json_db['mkey']['nDerivationMethod']

        if cry_method != 0:
            sys.stderr.write("%s: this wallet uses unknown key derivation method\n" % filename)
            continue

        cry_salt = json_db['mkey']['salt']
        if len(cry_salt) == 16:
            expected_mkey_len = 96
        elif len(cry_salt) == 36:
            expected_mkey_len = 160
        else:
            sys.stderr.write("%s: this wallet uses unsupported salt size\n" % filename)
            continue

        if len(json_db['mkey']['encrypted_key']) != expected_mkey_len:
            sys.stderr.write("%s: this wallet uses unsupported master key size\n" % filename)
            continue

        cry_master = json_db['mkey']['encrypted_key'][-64:]

        sys.stdout.write("$bitcoin$%s$%s$%s$%s$%s$2$00$2$00\n" %
            (len(cry_master), cry_master, len(cry_salt), cry_salt, cry_rounds))
