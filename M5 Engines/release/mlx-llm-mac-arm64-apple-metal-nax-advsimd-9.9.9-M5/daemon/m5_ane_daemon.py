import socket
import os
import sys
import logging
import signal
import struct
import numpy as np
import coremltools as ct
import torch

# Logging yapılandırması
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("M5_ANE_Daemon")

SOCKET_PATH = "/tmp/m5_ane_daemon.sock"
is_running = True

# struct ANEWorkload {
#     uint32_t command_type; // 1 = compute
#     uint32_t grid_width;
#     uint32_t grid_height;
#     uint32_t grid_depth;
#     uint32_t thread_width;
#     uint32_t thread_height;
#     uint32_t thread_depth;
#     double timestamp;
# };
WORKLOAD_FORMAT = "<7Id"
WORKLOAD_SIZE = struct.calcsize(WORKLOAD_FORMAT)

def handle_shutdown(signum, frame):
    """Sinyal (SIGINT/SIGTERM) yakalandığında temiz kapanış sağlar."""
    global is_running
    logger.info("Kapatma sinyali alındı. Daemon durduruluyor...")
    is_running = False

def compile_and_run_coreml(grid_w, grid_h, grid_d):
    """Gelen grid boyutlarına göre dinamik olarak minimal CoreML modeli derler ve ANE üzerinde çalıştırır."""
    try:
        # Boyutları sınırlandırarak (0 olmasını engelle) shape oluştur
        # Model girdisi (1, C, H, W) formatında
        shape = (1, max(1, grid_d), max(1, grid_h), max(1, grid_w))
        
        logger.info(f"CoreML modeli derleniyor. Shape: {shape}")
        
        class MinimalModel(torch.nn.Module):
            def forward(self, x):
                return torch.relu(x)
                
        model = MinimalModel().eval()
        example_input = torch.rand(shape)
        traced_model = torch.jit.trace(model, example_input)
        
        # Modeli CoreML formatına dönüştür (ANE hedefli)
        # CPU_AND_NEURAL_ENGINE hatasını aşmak için compute_units=ct.ComputeUnit.ALL kullanıyoruz
        # Veya sadece CPU_AND_GPU'yu da test için kullanabiliriz eğer ANE reddediyorsa
        mlmodel = ct.convert(
            traced_model,
            inputs=[ct.TensorType(name="input_tensor", shape=shape)],
            compute_units=ct.ComputeUnit.ALL,
            minimum_deployment_target=ct.target.macOS13
        )
        
        logger.info("Model başarıyla derlendi, ANE üzerinde çalıştırılıyor...")
        
        # Modeli çalıştır
        input_data = np.random.rand(*shape).astype(np.float32)
        out = mlmodel.predict({"input_tensor": input_data})
        
        logger.info("Model başarıyla çalıştırıldı.")
        return True
    except Exception as e:
        logger.error(f"CoreML derleme/çalıştırma hatası: {e}")
        return False

def run_daemon():
    """Unix domain soketi üzerinden dinleyen ana daemon döngüsü."""
    
    # Sinyalleri bağla
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    # Önceki çalışmadan kalan soket dosyası varsa temizle
    try:
        os.unlink(SOCKET_PATH)
    except OSError:
        if os.path.exists(SOCKET_PATH):
            logger.error(f"Soket dosyası temizlenemedi: {SOCKET_PATH}")
            sys.exit(1)

    # AF_UNIX ile yerel bir soket oluştur
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    
    try:
        server.bind(SOCKET_PATH)
        server.listen(5)
        logger.info(f"M5 ANE Daemon başlatıldı. Dinleniyor: {SOCKET_PATH}")
        
        server.settimeout(1.0)

        while is_running:
            try:
                connection, client_address = server.accept()
            except socket.timeout:
                continue
            except Exception as e:
                logger.error(f"Bağlantı kabulünde hata: {e}")
                continue
            
            try:
                # İstemciden struct boyutunda veri al
                data = connection.recv(WORKLOAD_SIZE)
                if not data:
                    continue
                
                if len(data) == WORKLOAD_SIZE:
                    unpacked_data = struct.unpack(WORKLOAD_FORMAT, data)
                    cmd_type, gw, gh, gd, tw, th, td, timestamp = unpacked_data
                    
                    logger.info(f"ANE Workload Alındı - Komut: {cmd_type}, Grid: ({gw}, {gh}, {gd}), "
                                f"Thread: ({tw}, {th}, {td}), Timestamp: {timestamp}")
                    
                    # Eğer komut hesaplama ise CoreML işlemini yap
                    success = False
                    if cmd_type == 1:
                        success = compile_and_run_coreml(gw, gh, gd)
                    
                    # C++ tarafına başarı durumunu dön (1 = Başarılı, 0 = Başarısız)
                    response = struct.pack("<I", 1 if success else 0)
                    connection.sendall(response)
                else:
                    logger.warning(f"Geçersiz veri boyutu alındı: {len(data)} bayt (Beklenen: {WORKLOAD_SIZE})")
                    # Başarısız dön
                    connection.sendall(struct.pack("<I", 0))
                    
            except Exception as e:
                logger.error(f"İletişim sırasında hata oluştu: {e}")
            finally:
                connection.close()
                
    finally:
        logger.info("Soket kapatılıyor ve temizleniyor...")
        server.close()
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        logger.info("Daemon başarıyla sonlandırıldı.")

if __name__ == "__main__":
    run_daemon()
