class AsymmetricController():
    def __init__(self, adjustment_rate, init_output):
        self.adjustment_rate = adjustment_rate
        self.output = init_output

    def feed(self, error):
        if (error < 0):
            self.output *= (1 - self.adjustment_rate)
        return self.output
