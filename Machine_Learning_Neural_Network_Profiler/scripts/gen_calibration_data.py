import os
import numpy as np
import argparse

def create_test_data_dir():
    test_data_dir = "../test_data"
    if not os.path.exists(test_data_dir):
        os.makedirs(test_data_dir)
        print(f"Created directory: {test_data_dir}")
    return test_data_dir

def generate_mnist_data(samples=1000, features=784, classes=10):
    X = np.random.random((samples, features)).astype(np.float32)
    y = np.random.randint(0, classes, samples)
    
    return X, y

def save_calibration_data(X, y, output_path):
    data = np.column_stack((y, X))
    
    np.savetxt(output_path, data, delimiter=',', fmt='%.6f')
    print(f"Saved calibration data: {output_path}")
    print(f"Shape: {data.shape} (target + {X.shape[1]} features)")

def main():
    parser = argparse.ArgumentParser(description='Generate calibration data for ML models')
    parser.add_argument('--samples', type=int, default=1000, help='Number of samples (default: 1000)')
    parser.add_argument('--features', type=int, default=784, help='Number of features (default: 784 for MNIST)')
    parser.add_argument('--classes', type=int, default=10, help='Number of classes (default: 10)')
    
    args = parser.parse_args()
    
    test_data_dir = create_test_data_dir()
    
    print(f"Generating {args.samples} samples with {args.features} features...")
    X, y = generate_mnist_data(args.samples, args.features, args.classes)
    
    output_path = os.path.join(test_data_dir, "test_data.csv")
    save_calibration_data(X, y, output_path)
    
    print(f"\nCalibration data ready for ML Configurator:")
    print(f"- feat_col_count: {args.features}")
    print(f"- feat_col_first: 1")
    print(f"- target_col_count: 1") 
    print(f"- target_col_first: 0")

if __name__ == "__main__":
    main()
