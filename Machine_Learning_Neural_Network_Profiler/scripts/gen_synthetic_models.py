import os
import sys
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import argparse

def create_directories():
    """Create necessary directories if they don't exist"""
    models_dir = "../pretrained_models"
    if not os.path.exists(models_dir):
        os.makedirs(models_dir)
        print(f"Created directory: {models_dir}")
    return models_dir

def create_small_model():
    """Create a small neural network model for MNIST-like data"""
    model = keras.Sequential([
        layers.Dense(64, activation='relu', input_shape=(784,), name='dense_1'),
        layers.Dropout(0.2, name='dropout_1'),
        layers.Dense(32, activation='relu', name='dense_2'),
        layers.Dense(10, activation='softmax', name='output')
    ], name='mnist_small_model')
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def create_medium_model():
    model = keras.Sequential([
        layers.Dense(128, activation='relu', input_shape=(784,), name='dense_1'),
        layers.Dropout(0.3, name='dropout_1'),
        layers.Dense(64, activation='relu', name='dense_2'),
        layers.Dropout(0.3, name='dropout_2'),
        layers.Dense(32, activation='relu', name='dense_3'),
        layers.Dense(10, activation='softmax', name='output')
    ], name='mnist_medium_model')
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def create_large_model():
    model = keras.Sequential([
        layers.Dense(256, activation='relu', input_shape=(784,), name='dense_1'),
        layers.Dropout(0.3, name='dropout_1'),
        layers.Dense(128, activation='relu', name='dense_2'),
        layers.Dropout(0.3, name='dropout_2'),
        layers.Dense(64, activation='relu', name='dense_3'),
        layers.Dropout(0.2, name='dropout_3'),
        layers.Dense(32, activation='relu', name='dense_4'),
        layers.Dense(10, activation='softmax', name='output')
    ], name='mnist_large_model')
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def train_model_with_synthetic_data(model, epochs=5):
    print(f"Training {model.name} with synthetic data...")
    
    x_train = np.random.random((1000, 784)).astype(np.float32)
    y_train = np.random.randint(0, 10, (1000,))
    
    model.fit(x_train, y_train, epochs=epochs, verbose=0, batch_size=32)
    print(f"Training completed for {model.name}")

def convert_to_tflite(model, model_path):
    tflite_path = model_path.replace('.h5', '.tflite')
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"Converted to TFLite: {tflite_path}")
    return tflite_path

def save_model(model, models_dir, model_name):
    h5_path = os.path.join(models_dir, f"{model_name}.h5")    
    model.save(h5_path)
    print(f"Saved H5 model: {h5_path}")
    tflite_path = convert_to_tflite(model, h5_path)    
    print(f"\nModel: {model_name}")
    print(f"Parameters: {model.count_params():,}")
    model.summary()
    
    return h5_path, tflite_path

def main():
    parser = argparse.ArgumentParser(description='Generate synthetic neural network models')
    parser.add_argument('--epochs', type=int, default=5, help='Training epochs for synthetic data (default: 5)')
    parser.add_argument('--models', nargs='+', choices=['small', 'medium', 'large'], 
                       default=['small', 'medium', 'large'], help='Models to generate')
    
    args = parser.parse_args()
    
    print("= GENERATING SYNTHETIC MODELS ===")
    models_dir = create_directories()
    
    model_generators = {
        'small': create_small_model,
        'medium': create_medium_model,
        'large': create_large_model
    }
    
    generated_models = []
    
    for model_type in args.models:
        print(f"\nGenerating {model_type} model...")
        
        model = model_generators[model_type]()
        train_model_with_synthetic_data(model, args.epochs)
        model_name = f"mnist_{model_type}"
        h5_path, tflite_path = save_model(model, models_dir, model_name)
        
        generated_models.append({
            'name': model_name,
            'type': model_type,
            'h5_path': h5_path,
            'tflite_path': tflite_path,
            'parameters': model.count_params()
        })
    
    print("\n=== SUMMARY ===")
    for model_info in generated_models:
        print(f" {model_info['name']} ({model_info['type']}) - {model_info['parameters']:,} parameters")
        print(f"  H5: {model_info['h5_path']}")
        print(f"  TFLite: {model_info['tflite_path']}")
    
    print(f"\nTotal models generated: {len(generated_models) * 2} files")
    print("Models are ready for testing with test_models.sh script")

if __name__ == "__main__":
    main()
