const net = require('net');
const { execSync, spawn } = require('child_process');

// Mantener la VM de WSL viva permanentemente sin que Windows la apague por inactividad
try {
  const keepAlive = spawn('wsl.exe', ['-d', 'podman-machine-default', 'sleep', 'infinity'], { stdio: 'ignore', detached: false });
  keepAlive.on('error', (e) => console.error('Keep-alive error:', e.message));
} catch (e) {}

function getWslIp() {
  try {
    const out = execSync('& "C:\\\\Users\\\\luis\\\\AppData\\\\Local\\\\Programs\\\\Podman\\\\podman.exe" machine ssh -- ip -4 -br addr show eth0', { shell: 'powershell.exe' }).toString();
    const parts = out.trim().split(/\s+/);
    if (parts.length >= 3) {
      return parts[2].split('/')[0];
    }
  } catch (e) {
    console.error('Error obteniendo IP de WSL:', e.message);
  }
  return '172.30.172.154';
}

const wslIp = getWslIp();

function forwardPort(port) {
  const server = net.createServer((clientSocket) => {
    const targetSocket = net.connect(port, wslIp);
    clientSocket.pipe(targetSocket);
    targetSocket.pipe(clientSocket);
    clientSocket.on('error', () => targetSocket.destroy());
    targetSocket.on('error', () => clientSocket.destroy());
  });
  server.on('error', (err) => {
    if (err.code !== 'EADDRINUSE') {
      console.error(`Error en puerto ${port}:`, err);
    }
  });
  server.listen(port, '127.0.0.1', () => {
    console.log(`[Proxy] 127.0.0.1:${port} -> ${wslIp}:${port}`);
  });
}

forwardPort(3000);
forwardPort(5434);
