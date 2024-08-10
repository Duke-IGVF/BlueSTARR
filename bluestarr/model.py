
import keras.layers as kl
from keras.models import Model as KerasModel
import keras.optimizers as opt
import keras_nlp as nlp

from .modelconfig import ModelConfig
from .utils import int_shape

class Model:

    @staticmethod
    def from_config(config: ModelConfig) -> ModelConfig:
        model = Model(config=config)
        return model

    @staticmethod
    def from_config_file(filename: str) -> ModelConfig:
        config = ModelConfig(config_file=filename)
        return Model.from_config(config)
    
    def __init__(self, config: ModelConfig=None, seqlen: int=None):
        if config is not None:
            self.build(config, seqlen=seqlen)
    
    def build(self, config: ModelConfig, seqlen: int=None):
        # Input layer
        inputLayer = kl.Input(shape=(seqlen,4))
        x = inputLayer

        # Optional convolutional layers
        skip=None
        for i in range(config.NumConvLayers):
            # if (config.KernelSizes[i]>=seqlen): continue
            dilation = 1 if i==0 else config.DilationFactor
            if (i > 0 and config.ConvDropout != 0):
                x = kl.Dropout(config.DropoutRate)(x)
            x = kl.Conv1D(config.NumKernels[i],
                          kernel_size=config.KernelSizes[i],
                          padding=config.ConvPad,
                          dilation_rate=dilation)(x)
            x = kl.BatchNormalization()(x)
            x = kl.Activation('relu')(x)
            if (config.ConvPoolSize > 1 and seqlen > config.ConvPoolSize):
                x = kl.MaxPooling1D(config.ConvPoolSize)(x)
                seqlen /= config.ConvPoolSize
            
        # Optional attention layers
        if (config.NumAttn>0):
            x = x + nlp.layers.SinePositionEncoding()(x)
        for i in range(config.NumAttn):
            skip = x
            x = kl.LayerNormalization()(x)
            x = kl.MultiHeadAttention(num_heads=config.AttentionHeads[i],
                                      key_dim=config.AttentionKeyDim[i])(x,x)
            x = kl.Dropout(config.DropoutRate)(x)
            if (config.AttentionResidualSkip != 0):
                x = kl.Add()([x,skip])

        # Global pooling
        if (config.GlobalMaxPool != 0):
            x = kl.MaxPooling1D(int_shape(x)[1])(x)
        if (config.GlobalAvePool != 0):
            x = kl.AveragePooling1D(int_shape(x)[1])(x)
    
        # Flatten
        if (config.Flatten != 0):
            x = kl.Flatten()(x)

        # dense layers
        if (config.NumDense > 0):
            x = kl.Dropout(config.DropoutRate)(x)
        for i in range(config.NumDense):
            x = kl.Dense(config.DenseSizes[i])(x)
            x = kl.BatchNormalization()(x)
            x = kl.Activation('relu')(x)
            x = kl.Dropout(config.DropoutRate)(x)
    
        # Heads per cell type
        outputs=[]
        for task in config.getlist('Tasks'):
            outputs.append(kl.Dense(1, activation='linear', name=task)(x))
        self.config = config
        self.model = KerasModel([inputLayer], outputs)
        return self
    
    def compile(self, optimizer=None, loss="mse", loss_weights=None, run_eagerly=True, **kwargs):
        if optimizer is None:
            optimizer = opt.Adam(learning_rate=self.config.LearningRate)
        if (loss_weights is None) and (self.config.numTasks > 1):
            loss_weights = self.config.getlist('TaskWeights')
        self.model.compile(optimizer=optimizer,
                           loss=loss,
                           loss_weights=loss_weights,
                           run_eagerly=run_eagerly,
                           **kwargs)