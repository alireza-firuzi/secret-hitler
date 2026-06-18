const { WebSocketServer } = require('ws');
const http = require('http');

const PORT = process.env.PORT || 3000;

// Create HTTP Server
const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Secret Hitler WebSocket Sync Server is running.\n');
});

// Create WebSocket Server
const wss = new WebSocketServer({ server });

// Memory databases
const games = {}; // lobbyCode -> public game state
const privateRoles = {}; // lobbyCode -> { playerId -> roleData }
const clientLobbies = new Map(); // ws client -> lobbyCode
const clientPlayerIds = new Map(); // ws client -> playerId

function generateLobbyCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code;
  do {
    code = Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
  } while (games[code]);
  return code;
}

// Broadcast game state to everyone in a lobby
function broadcast(lobbyCode) {
  const gameState = games[lobbyCode];
  if (!gameState) return;

  const payload = JSON.stringify({
    type: 'sync',
    data: gameState,
  });

  for (const client of wss.clients) {
    if (client.readyState === 1 && clientLobbies.get(client) === lobbyCode) {
      client.send(payload);
    }
  }
}

wss.on('connection', (ws) => {
  console.log('New connection established.');

  ws.on('message', (message) => {
    try {
      const payload = JSON.parse(message);
      const { action, lobbyCode, playerId } = payload;

      console.log(`Action received: ${action} | Player: ${playerId} | Lobby: ${lobbyCode}`);

      switch (action) {
        case 'create': {
          const { hostName } = payload;
          const code = generateLobbyCode();
          
          const newGame = {
            lobbyCode: code,
            status: 'lobby',
            hostId: playerId,
            playerIds: [playerId],
            players: [
              {
                id: playerId,
                name: hostName,
                isAlive: true,
                isInvestigated: false,
              }
            ],
            liberalPolicies: 0,
            fascistPolicies: 0,
            electionTracker: 0,
            presidentIndex: 0,
            chancellorIndex: -1,
            nominatedChancellorIndex: -1,
            previousPresidentIndex: -1,
            previousChancellorIndex: -1,
            phase: 'setup',
            activePower: 'none',
            votes: {},
            drawnPolicies: [],
            logs: [`${hostName} created the game lobby.`],
            winner: null,
            winReason: null,
            investigatedParty: null,
            investigatedPlayerIndex: -1,
          };

          games[code] = newGame;
          privateRoles[code] = {};

          clientLobbies.set(ws, code);
          clientPlayerIds.set(ws, playerId);

          ws.send(JSON.stringify({
            type: 'created',
            lobbyCode: code,
            data: newGame,
          }));
          break;
        }

        case 'join': {
          const { playerName } = payload;
          const game = games[lobbyCode];

          if (!game) {
            ws.send(JSON.stringify({ type: 'error', message: 'Lobby code not found.' }));
            return;
          }

          if (game.status !== 'lobby') {
            ws.send(JSON.stringify({ type: 'error', message: 'Game already in progress.' }));
            return;
          }

          const players = game.players;
          const playerIds = game.playerIds;

          if (players.length >= 10) {
            ws.send(JSON.stringify({ type: 'error', message: 'Lobby is full.' }));
            return;
          }

          clientLobbies.set(ws, lobbyCode);
          clientPlayerIds.set(ws, playerId);

          if (!playerIds.includes(playerId)) {
            playerIds.push(playerId);
            players.push({
              id: playerId,
              name: playerName,
              isAlive: true,
              isInvestigated: false,
            });
            game.logs.push(`${playerName} joined the lobby.`);
          }

          // Acknowledge join
          ws.send(JSON.stringify({
            type: 'joined',
            lobbyCode: lobbyCode,
            data: game,
          }));

          // Notify everyone in the lobby
          broadcast(lobbyCode);
          break;
        }

        case 'subscribe': {
          const game = games[lobbyCode];
          if (game) {
            clientLobbies.set(ws, lobbyCode);
            clientPlayerIds.set(ws, playerId);
            ws.send(JSON.stringify({
              type: 'sync',
              data: game,
            }));
          } else {
            ws.send(JSON.stringify({ type: 'error', message: 'Lobby not found.' }));
          }
          break;
        }

        case 'update': {
          const { updates } = payload;
          const game = games[lobbyCode];
          
          if (game) {
            Object.assign(game, updates);
            broadcast(lobbyCode);
          }
          break;
        }

        case 'savePrivateRoles': {
          const { playerRoles } = payload;
          if (!privateRoles[lobbyCode]) {
            privateRoles[lobbyCode] = {};
          }
          Object.assign(privateRoles[lobbyCode], playerRoles);
          break;
        }

        case 'getPrivateRole': {
          const roles = privateRoles[lobbyCode];
          const roleData = roles ? roles[playerId] : null;
          ws.send(JSON.stringify({
            type: 'privateRole',
            lobbyCode: lobbyCode,
            playerId: playerId,
            data: roleData,
          }));
          break;
        }
      }
    } catch (err) {
      console.error('Error handling message:', err);
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid server action.' }));
    }
  });

  ws.on('close', () => {
    const lobbyCode = clientLobbies.get(ws);
    const playerId = clientPlayerIds.get(ws);
    
    console.log(`Connection closed: Player ${playerId} from Lobby ${lobbyCode}`);

    clientLobbies.delete(ws);
    clientPlayerIds.delete(ws);

    // Optional: We can clean up empty lobbies after some time, but keep active for dev testing.
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is listening on port ${PORT}`);
});
