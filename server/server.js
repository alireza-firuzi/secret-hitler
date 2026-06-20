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

// Heartbeat keep-alive ping loop
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      console.log('Heartbeat missed. Terminating connection.');
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 5000);

wss.on('close', () => {
  clearInterval(interval);
});

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
  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('message', (message) => {
    try {
      const payload = JSON.parse(message);
      const { action, lobbyCode, playerId } = payload;

      console.log(`Action received: ${action} | Player: ${playerId} | Lobby: ${lobbyCode}`);

      switch (action) {
        case 'create': {
          const { hostName, avatar } = payload;
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
                avatar: avatar || 'avatar_1',
                isAlive: true,
                isInvestigated: false,
                isDisconnected: false,
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
          const { playerName, avatar } = payload;
          const game = games[lobbyCode];

          if (!game) {
            ws.send(JSON.stringify({ type: 'error', message: 'کد لابی یافت نشد.' }));
            return;
          }

          const existingPlayer = game.players.find(p => p.name === playerName);
          if (existingPlayer) {
            if (!existingPlayer.isDisconnected) {
              ws.send(JSON.stringify({ type: 'error', message: 'این نام قبلاً گرفته شده است. لطفاً نام دیگری انتخاب کنید.' }));
              return;
            } else {
              // Reconnect the player with their new playerId
              const oldPlayerId = existingPlayer.id;
              if (game.hostId === oldPlayerId) {
                game.hostId = playerId;
              }
              const idx = game.playerIds.indexOf(oldPlayerId);
              if (idx !== -1) {
                game.playerIds[idx] = playerId;
              }
              existingPlayer.id = playerId;
              existingPlayer.isDisconnected = false;

              if (game.votes && game.votes[oldPlayerId] !== undefined) {
                game.votes[playerId] = game.votes[oldPlayerId];
                delete game.votes[oldPlayerId];
              }
              if (privateRoles[lobbyCode] && privateRoles[lobbyCode][oldPlayerId]) {
                privateRoles[lobbyCode][playerId] = privateRoles[lobbyCode][oldPlayerId];
                delete privateRoles[lobbyCode][oldPlayerId];
              }

              clientLobbies.set(ws, lobbyCode);
              clientPlayerIds.set(ws, playerId);

              game.logs.push(`${playerName} مجدداً به بازی متصل شد.`);

              // Acknowledge join/rejoin
              ws.send(JSON.stringify({
                type: 'joined',
                lobbyCode: lobbyCode,
                data: game,
              }));

              // Notify everyone
              broadcast(lobbyCode);
              return;
            }
          }

          // New player joining
          if (game.status !== 'lobby') {
            ws.send(JSON.stringify({ type: 'error', message: 'بازی در حال انجام است.' }));
            return;
          }

          if (game.players.length >= 10) {
            ws.send(JSON.stringify({ type: 'error', message: 'ظرفیت لابی پر شده است.' }));
            return;
          }

          clientLobbies.set(ws, lobbyCode);
          clientPlayerIds.set(ws, playerId);

          game.playerIds.push(playerId);
          game.players.push({
            id: playerId,
            name: playerName,
            avatar: avatar || 'avatar_1',
            isAlive: true,
            isInvestigated: false,
            isDisconnected: false,
          });
          game.logs.push(`${playerName} به لابی پیوست.`);

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

    if (lobbyCode && playerId) {
      const game = games[lobbyCode];
      if (game) {
        if (game.status === 'lobby') {
          // Remove player from lobby
          const playerIndex = game.players.findIndex(p => p.id === playerId);
          if (playerIndex !== -1) {
            const name = game.players[playerIndex].name;
            game.players.splice(playerIndex, 1);
            const idIndex = game.playerIds.indexOf(playerId);
            if (idIndex !== -1) {
              game.playerIds.splice(idIndex, 1);
            }
            game.logs.push(`${name} از لابی خارج شد.`);
            
            // If host left, assign new host or delete lobby if empty
            if (game.hostId === playerId) {
              if (game.players.length > 0) {
                game.hostId = game.players[0].id;
                game.logs.push(`${game.players[0].name} میزبان جدید لابی شد.`);
              } else {
                delete games[lobbyCode];
                delete privateRoles[lobbyCode];
                console.log(`Lobby ${lobbyCode} deleted as it became empty.`);
                return;
              }
            }
            broadcast(lobbyCode);
          }
        } else {
          // Game is in progress, mark as disconnected and pause
          const player = game.players.find(p => p.id === playerId);
          if (player) {
            player.isDisconnected = true;
            console.log(`Player ${player.name} in lobby ${lobbyCode} marked as disconnected.`);
            game.logs.push(`ارتباط ${player.name} با بازی قطع شد.`);
            broadcast(lobbyCode);
          }
        }
      }
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is listening on port ${PORT}`);
});
