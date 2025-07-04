from keras.layers import IntegerLookup
import numpy as np
from .utils import reshape

class DNAEncoding(IntegerLookup):
    def __init__(self,
                 seqlen=None,
                 vocabulary='ACGT',
                 mask_token='N',
                 ignore_case=True,
                 **kwargs):
        vocabulary = [ord(c) for c in list(vocabulary)]
        if mask_token is not None:
            mask_token = ord(mask_token)
        super().__init__(vocabulary=vocabulary,
                         mask_token=mask_token,
                         num_oov_indices=0,
                         output_mode='one_hot',
                         **kwargs)
        self.ignore_case = ignore_case
        self.seqlen = seqlen

    def build(self, input_shape):
        super().build(input_shape)

    def call(self, inputs):
        # Implement your DNA encoding logic here
        input_shape = inputs.shape
        seqs = reshape(inputs, (-1))
        print(inputs)
        if isinstance(seqs[0], str):
            seqs = [bytes(seq, 'utf-8') for seq in seqs]
        seqs = [list(seq) for seq in seqs]
        print(seqs)
        encoded_dna = [super(DNAEncoding,self).call(seq) for seq in seqs]
        print(encoded_dna)        
        return reshape(encoded_dna, self.compute_output_shape(input_shape))

    def compute_output_shape(self, input_shape):
        return input_shape + (self.seqlen, self.vocabulary_size)