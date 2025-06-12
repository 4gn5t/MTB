import serial
import time

try:
    # Вкажи свій порт - increase timeout for more reliable communication
    port = serial.Serial("COM9", 1000000, timeout=5)
    time.sleep(2)  # Даємо платі час на старт

    # Wait for device to be ready (look for "Waiting for the data stream to begin...")
    print("Waiting for device to be ready...")
    start = time.time()
    response_data = b""
    
    while time.time() - start < 15:  # Wait up to 15 seconds for device ready
        if port.in_waiting > 0:
            chunk = port.read(port.in_waiting)
            response_data += chunk
            text = chunk.decode(errors='ignore')
            print(f"Device output: {text.strip()}")
            
            # Check if device is waiting for data stream
            if b"Waiting for the data stream to begin" in response_data:
                print("✅ Device is ready, sending ML_START...")
                break
        time.sleep(0.1)
    else:
        print("⚠️ Device not ready, sending ML_START anyway...")

    # Надсилаємо ML_START (without line endings as C code expects exact match)
    print("Sending ML_START...")
    port.write(b"ML_START")
    port.flush()  # Ensure data is sent immediately

    # Читаємо відповідь
    print("Waiting for ML_READY response...")
    start = time.time()
    response_data = b""
    
    while time.time() - start < 10:  # чекаємо до 10 секунд
        if port.in_waiting > 0:
            chunk = port.read(port.in_waiting)
            response_data += chunk
            text = chunk.decode(errors='ignore')
            print(f"Received: {text.strip()}")
            
            # Check if we received ML_READY (expected response)
            if b"ML_READY" in response_data:
                print("✅ Received ML_READY - connection established!")
                break
        time.sleep(0.1)  # Small delay to prevent busy waiting
    else:
        print("⚠️ No ML_READY response after ML_START")

    port.close()

except serial.SerialException as e:
    print(f"❌ Serial communication error: {e}")
except Exception as e:
    print(f"❌ Unexpected error: {e}")
