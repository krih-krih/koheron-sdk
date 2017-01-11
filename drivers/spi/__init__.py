
from koheron import command, connect

class Spi(object):
    def __init__(self, client):
        self.client = client

    @command()
    def write(self, data):
        return self.client.recv_int32()

    @command()
    def set_speed(self, speed): pass

if __name__ == "__main__":
    import os
    import numpy as np

    host = os.getenv('HOST','192.168.1.100')
    client = connect(host, name='oscillo')
    spi = Spi(client)
    spi.set_speed(1000000)
    spi.write(np.array([2045, 4, 8, 16, 32, 64, 128, 256], dtype='uint32'))