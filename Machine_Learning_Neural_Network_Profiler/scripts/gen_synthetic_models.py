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

def create_extra_large_model():
    """Create an extra large neural network model for MNIST-like data"""
    model = keras.Sequential([
        layers.Dense(512, activation='relu', input_shape=(784,), name='dense_1'),
        layers.Dropout(0.4, name='dropout_1'),
        layers.Dense(256, activation='relu', name='dense_2'),
        layers.Dropout(0.4, name='dropout_2'),
        layers.Dense(128, activation='relu', name='dense_3'),
        layers.Dropout(0.3, name='dropout_3'),
        layers.Dense(64, activation='relu', name='dense_4'),
        layers.Dense(10, activation='softmax', name='output')
    ], name='mnist_extra_large_model')
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

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
    """Create a medium neural network model for MNIST-like data"""
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
    """Create a large neural network model for MNIST-like data"""
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
    """Train the model with synthetic data"""
    print(f"Training {model.name} with synthetic data...")
    
    x_train = np.random.random((1000, 784)).astype(np.float32)
    y_train = np.random.randint(0, 10, (1000,))
    
    model.fit(x_train, y_train, epochs=epochs, verbose=0, batch_size=32)
    print(f"Training completed for {model.name}")

def convert_to_tflite(model, model_path, quantization_type="float32"):
    """Convert the Keras model to TFLite format with specified quantization"""
    if quantization_type == "float32":
        tflite_path = model_path.replace('.h5', '.tflite')
    else:
        tflite_path = model_path.replace('.h5', f'_{quantization_type}.tflite')
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    if quantization_type == "int8x8":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.int8]
        def representative_dataset():
            for _ in range(100):
                yield [np.random.random((1, 784)).astype(np.float32)]
        converter.representative_dataset = representative_dataset
    elif quantization_type == "int16x16":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.int16]
    elif quantization_type == "int16x8":
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.int16]
    else:  
        converter.optimizations = [tf.lite.Optimize.OPTIMIZE_FOR_SIZE]
    
    tflite_model = converter.convert()
    
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    
    print(f"Converted to TFLite ({quantization_type}): {tflite_path}")
    return tflite_path

def save_model(model, models_dir, model_name, quantization_types=None):
    """Save the Keras model in H5 and multiple TFLite formats"""
    if quantization_types is None:
        quantization_types = ["float32"]
    
    h5_path = os.path.join(models_dir, f"{model_name}.h5")    
    model.save(h5_path)
    print(f"Saved H5 model: {h5_path}")
    
    tflite_paths = []
    for quant_type in quantization_types:
        try:
            tflite_path = convert_to_tflite(model, h5_path, quant_type)
            tflite_paths.append(tflite_path)
        except Exception as e:
            print(f"Warning: Failed to convert {model_name} to {quant_type}: {e}")
    
    print(f"\nModel: {model_name}")
    print(f"Parameters: {model.count_params():,}")
    model.summary()
    
    return h5_path, tflite_paths

def main():


    parser = argparse.ArgumentParser(description='Generate synthetic neural network models')
    parser.add_argument('--epochs', type=int, default=5, help='Training epochs for synthetic data (default: 5)')
    parser.add_argument('--models', nargs='+', choices=['small', 'medium', 'large'], default=['small', 'medium', 'large'], help='Models to generate')
    parser.add_argument('--quantization', nargs='+', choices=['float32', 'int16x16', 'int16x8', 'int8x8'], default=['float32'], help='Quantization types to generate (default: float32)')
    parser.add_argument('--tflite-only', action='store_true', help='Generate only base TFLite files without quantization suffixes')
    
    args = parser.parse_args()
    
    models_dir = create_directories()
    
    if args.tflite_only:
        print("Note: Generating base TFLite files only (no quantization suffixes)")
        quantization_types = ['float32']
    else:
        quantization_types = args.quantization
    
    model_generators = {
        'small': create_small_model,
        'medium': create_medium_model,
        'large': create_large_model,
        'extra_large': create_extra_large_model
    }
    
    generated_models = []
    
    for model_type in args.models:
        print(f"\nGenerating {model_type} model...")
        
        model = model_generators[model_type]()
        train_model_with_synthetic_data(model, args.epochs)
        model_name = f"mnist_{model_type}"
        h5_path, tflite_paths = save_model(model, models_dir, model_name, quantization_types)
        
        generated_models.append({
            'name': model_name,
            'type': model_type,
            'h5_path': h5_path,
            'tflite_paths': tflite_paths,
            'parameters': model.count_params(),
            'quantization_types': quantization_types
        })
    
    print("\n=== SUMMARY ===")
    for model_info in generated_models:
        print(f"{model_info['name']} ({model_info['type']}) - {model_info['parameters']:,} parameters")
        print(f"  H5: {model_info['h5_path']}")
        for tflite_path in model_info['tflite_paths']:
            print(f"  TFLite: {tflite_path}")
    
    total_files = sum(1 + len(model_info['tflite_paths']) for model_info in generated_models)
    print(f"\nTotal models generated: {total_files} files")
    print("Models are ready for testing with test_models.sh script")

if __name__ == "__main__":
    main()
