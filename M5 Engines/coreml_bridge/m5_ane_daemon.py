import socket
import os
import sys
import logging
import signal

# Logging yapılandırması
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("M5_ANE_Daemon")

SOCKET_PATH = "/tmp/m5_ane.sock"
is_running = True

def handle_shutdown(signum, frame):
    """Sinyal (SIGINT/SIGTERM) yakalandığında temiz kapanış sağlar."""
    global is_running
    logger.info("Kapatma sinyali alındı. Daemon durduruluyor...")
    is_running = False

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

    # AF_UNIX ile yerel bir soket oluştur (sadece aynı makinedeki işlemler için güvenli)
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    
    try:
        server.bind(SOCKET_PATH)
        server.listen(5) # Maksimum 5 bekleyen bağlantı
        logger.info(f"M5 ANE Daemon başlatıldı. Dinleniyor: {SOCKET_PATH}")
        
        # Timeout ekleyerek while döngüsünün sinyalleri işleyebilmesini sağlıyoruz
        server.settimeout(1.0)

        while is_running:
            try:
                connection, client_address = server.accept()
            except socket.timeout:
                continue # Sinyal kontrolü için fırsat
            except Exception as e:
                logger.error(f"Bağlantı kabulünde hata: {e}")
                continue

            logger.info("Yeni bir istemci bağlandı.")
            
            try:
                while is_running:
                    # İstemciden veri al
                    data = connection.recv(4096)
                    if not data:
                        logger.info("İstemci bağlantıyı kapattı.")
                        break
                    
                    decoded_data = data.decode('utf-8').strip()
                    logger.info(f"Alınan komut: {decoded_data}")
                    
                    # Basit bir cevap dön (ACK)
                    response = f"ACK: '{decoded_data}' komutu işleme alındı.\n"
                    connection.sendall(response.encode('utf-8'))
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
