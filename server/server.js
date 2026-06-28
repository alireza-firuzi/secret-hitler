const { WebSocketServer } = require('ws');
const http = require('http');
const { MsEdgeTTS, OUTPUT_FORMAT } = require('msedge-tts');

const PORT = process.env.PORT || 3000;

// Create HTTP Server
const server = http.createServer(async (req, res) => {
  const urlObj = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  
  if (urlObj.pathname === '/api/tts') {
    const text = urlObj.searchParams.get('text');
    if (!text) {
      res.writeHead(400, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end('Missing text parameter');
      return;
    }

    try {
      const tts = new MsEdgeTTS();
      await tts.setMetadata("fa-IR-DilaraNeural", OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
      
      res.writeHead(200, {
        'Content-Type': 'audio/mpeg',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Cache-Control': 'public, max-age=3600'
      });

      const { audioStream } = tts.toStream(text);
      audioStream.pipe(res);
    } catch (e) {
      console.error("TTS Proxy Error:", e);
      res.writeHead(500, { 'Content-Type': 'text/plain', 'Access-Control-Allow-Origin': '*' });
      res.end('Error proxying Edge TTS');
    }
    return;
  }

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
const { MongoClient } = require('mongodb');

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

async function generateNarration(phase, detail = '') {
  console.log(`[AI Narrator] Generating narration for event: ${phase} (${detail})`);
  if (!GEMINI_API_KEY) {
    console.log(`[AI Narrator] No Gemini API Key set, using fallback.`);
    return getFallbackNarration(phase, detail);
  }

  const prompt = `You are a theatrical, dark, mysterious 1930s Persian game narrator for "Secret Hitler". 
Write a short, highly atmospheric narration (maximum 15 words) in Persian (using Persian script, no English, no Finglish) for the following game event:
Event: ${phase}
Additional Detail: ${detail}
Output ONLY the Persian narration text. No quotes, no explanations.`;

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }]
      })
    });
    const data = await response.json();
    console.log("[AI Narrator] Gemini response data:", JSON.stringify(data));
    if (data.candidates && data.candidates[0] && data.candidates[0].content && data.candidates[0].content.parts[0]) {
      const text = data.candidates[0].content.parts[0].text.trim();
      if (text) {
        console.log(`[AI Narrator] Success! Text: ${text}`);
        return text;
      }
    }
  } catch (e) {
    console.error("[AI Narrator] Gemini API Error:", e);
  }
  console.log(`[AI Narrator] Falling back to pre-recorded template.`);
  return getFallbackNarration(phase, detail);
}

function getFallbackNarration(phase, detail) {
  const fallbacks = {
    'setup': 'بازی آغاز شد. فاشیست‌ها در سایه و لیبرال‌ها در پی حقیقت هستند.',
    'discussion': 'فاز بحث و گفت‌وگو آغاز شد. به صحبت‌های یکدیگر گوش دهید و فاشیست‌ها را شناسایی کنید.',
    'president_reveal': `رئیس‌جمهور جدید ${detail} است. نامزد خود برای صدراعظمی را معرفی کند.`,
    'president_reveal_hitler_warning': `رئیس‌جمهور جدید ${detail} است. هشدار: ۳ یا بیشتر قانون فاشیستی تصویب شده است! اگر هیتلر به عنوان صدراعظم انتخاب شود، فاشیست‌ها فوراً برنده خواهند شد!`,
    'vote_passed': 'رای‌گیری با موفقیت تصویب شد. دولت جدید مستقر می‌شود.',
    'vote_failed': 'رای‌گیری شکست خورد. هرج و مرج در مجلس حاکم است.',
    'policy_liberal': 'یک قانون لیبرال تصویب شد. دموکراسی زنده است.',
    'policy_fascist': 'یک قانون فاشیست تصویب شد. سایه دیکتاتوری نزدیک‌تر می‌شود.',
    'power_execution': 'قانون فاشیستی جدید تصویب شد! رئیس‌جمهور قدرت اعدام دارد. او باید یک بازیکن را برای همیشه از بازی حذف کند.',
    'power_investigate': 'قانون فاشیستی جدید تصویب شد! رئیس‌جمهور قدرت تفحص دارد. او می‌تواند وفاداری حزبی یکی از بازیکنان را بررسی کند.',
    'power_election': 'قانون فاشیستی جدید تصویب شد! رئیس‌جمهور قدرت انتخابات ویژه دارد. او می‌تواند کاندیدای بعدی ریاست‌جمهوری را منصوب کند.',
    'power_peek': 'قانون فاشیستی جدید تصویب شد! رئیس‌جمهور قدرت پیش‌بینی دارد. او می‌تواند ۳ کارت بالای دسته سیاست‌ها را نگاه کند.',
    'game_win_liberal': 'لیبرال‌ها پیروز شدند! صلح و آزادی بازگشت.',
    'game_win_fascist': 'فاشیست‌ها پیروز شدند! هیتلر به قدرت رسید.'
  };
  return fallbacks[phase] || 'رویداد جدیدی در بازی ثبت شد.';
}

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/secret_hitler';
let db = null;
let gamesCollection = null;
let privateRolesCollection = null;
let usersCollection = null;

const games = {}; // lobbyCode -> public game state
const privateRoles = {}; // lobbyCode -> { playerId -> roleData }
const clientLobbies = new Map(); // ws client -> lobbyCode
const clientPlayerIds = new Map(); // ws client -> playerId

async function connectDB() {
  try {
    const client = new MongoClient(MONGODB_URI, { 
      connectTimeoutMS: 5000,
      serverSelectionTimeoutMS: 5000
    });
    await client.connect();
    db = client.db();
    gamesCollection = db.collection('games');
    privateRolesCollection = db.collection('privateRoles');
    usersCollection = db.collection('users');
    console.log('Connected successfully to MongoDB');

    // Load active games on startup
    const dbGames = await gamesCollection.find({}).toArray();
    for (const g of dbGames) {
      delete g._id; // Remove MongoDB specific ID to avoid issues on client side
      games[g.lobbyCode] = g;
    }
    const dbPrivateRoles = await privateRolesCollection.find({}).toArray();
    for (const pr of dbPrivateRoles) {
      privateRoles[pr.lobbyCode] = pr.roles || {};
    }
    console.log(`Loaded ${dbGames.length} active games and ${dbPrivateRoles.length} private roles from MongoDB.`);
  } catch (err) {
    console.warn('MongoDB connection failed. Running in memory-only mode:', err.message);
    db = null;
  }
}

connectDB();

async function saveGameToDB(lobbyCode) {
  if (!db) return;
  try {
    const game = games[lobbyCode];
    if (game) {
      const gameClone = { ...game };
      await gamesCollection.replaceOne({ lobbyCode }, gameClone, { upsert: true });
    }
  } catch (err) {
    console.error('Error saving game to MongoDB:', err);
  }
}

async function savePrivateRolesToDB(lobbyCode) {
  if (!db) return;
  try {
    const roles = privateRoles[lobbyCode];
    if (roles) {
      await privateRolesCollection.replaceOne({ lobbyCode }, { lobbyCode, roles }, { upsert: true });
    }
  } catch (err) {
    console.error('Error saving private roles to MongoDB:', err);
  }
}

async function deleteGameFromDB(lobbyCode) {
  if (!db) return;
  try {
    await gamesCollection.deleteOne({ lobbyCode });
    await privateRolesCollection.deleteOne({ lobbyCode });
  } catch (err) {
    console.error('Error deleting game from MongoDB:', err);
  }
}

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

  // Persist to MongoDB
  saveGameToDB(lobbyCode);
}

async function updatePlayersStats(lobbyCode, winningFaction) {
  if (!db || !usersCollection) return;
  try {
    const game = games[lobbyCode];
    const roles = privateRoles[lobbyCode];
    if (!game || !roles) return;

    console.log(`Game ended in lobby ${lobbyCode}. Faction winner: ${winningFaction}. Updating player stats.`);

    for (const player of game.players) {
      const playerId = player.id;
      const roleData = roles[playerId];
      if (!roleData) continue;

      const role = roleData.role; // 'Liberal', 'Fascist', or 'Secret Hitler'
      let isWin = false;
      if (winningFaction === 'Liberals') {
        isWin = (role === 'Liberal');
      } else if (winningFaction === 'Fascists') {
        isWin = (role === 'Fascist' || role === 'Secret Hitler');
      }

      const user = await usersCollection.findOne({ uid: playerId });
      if (user) {
        const update = {
          $inc: {
            'stats.gamesPlayed': 1,
            'stats.wins': isWin ? 1 : 0,
            'stats.losses': isWin ? 0 : 1,
            [`stats.roles.${role}`]: 1
          }
        };
        await usersCollection.updateOne({ uid: playerId }, update);
        console.log(`Updated stats for user ${user.displayName} (UID: ${playerId}). Won: ${isWin}`);
      }
    }
  } catch (err) {
    console.error('Error updating player stats:', err);
  }
}

function hasActiveConnection(lobbyCode, playerId, currentWs) {
  for (const client of wss.clients) {
    if (client !== currentWs &&
        client.readyState === 1 &&
        clientLobbies.get(client) === lobbyCode &&
        clientPlayerIds.get(client) === playerId) {
      return true;
    }
  }
  return false;
}

wss.on('connection', (ws) => {
  console.log('New connection established.');
  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('message', async (message) => {
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
            discussionDuration: 60,
            activeDiscussionPlayerIndex: -1,
            discussionEndTime: 0,
          };

          games[code] = newGame;
          privateRoles[code] = {};
          saveGameToDB(code);
          savePrivateRolesToDB(code);

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

          // Check for duplicate avatar
          const isAvatarTaken = game.players.some(p => p.avatar === avatar);
          if (isAvatarTaken) {
            ws.send(JSON.stringify({ type: 'error', message: 'این آواتار قبلاً توسط بازیکن دیگری انتخاب شده است.' }));
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

        case 'addBots': {
          const game = games[lobbyCode];
          if (!game) {
            ws.send(JSON.stringify({ type: 'error', message: 'کد لابی یافت نشد.' }));
            return;
          }

          const botNames = ['علیرضا', 'محمد', 'طلایه', 'پریچهر', 'سجاد', 'حمید', 'حدیث', 'فربد', 'حسن', 'کاظم'];
          const botAvatars = ['avatar_2', 'avatar_3', 'avatar_4', 'avatar_5', 'avatar_6', 'avatar_7', 'avatar_8', 'avatar_9', 'avatar_10', 'avatar_11'];

          let botsAdded = 0;
          for (let i = 0; i < botNames.length; i++) {
            if (botsAdded >= 5) break;
            if (game.players.length >= 10) break;
            
            const botName = botNames[i];
            const botAvatar = botAvatars[i];
            const botId = `bot_${Math.random().toString(36).substr(2, 9)}`;

            // Check if this bot name or avatar is already taken
            const isNameTaken = game.players.some(p => p.name === botName);
            const isAvatarTaken = game.players.some(p => p.avatar === botAvatar);

            if (!isNameTaken && !isAvatarTaken) {
              game.playerIds.push(botId);
              game.players.push({
                id: botId,
                name: botName,
                avatar: botAvatar,
                isAlive: true,
                isInvestigated: false,
                isDisconnected: false,
                isBot: true,
              });
              game.logs.push(`${botName} (ربات) به لابی پیوست.`);
              botsAdded++;
            }
          }

          if (botsAdded > 0) {
            broadcast(lobbyCode);
          }
          break;
        }

        case 'checkLobby': {
          const game = games[lobbyCode];
          if (!game) {
            ws.send(JSON.stringify({ type: 'error', message: 'کد لابی یافت نشد.' }));
            return;
          }
          const takenAvatars = game.players.map(p => p.avatar || 'avatar_1');
          ws.send(JSON.stringify({
            type: 'lobbyChecked',
            lobbyCode: lobbyCode,
            takenAvatars: takenAvatars,
          }));
          break;
        }

        case 'leave': {
          const game = games[lobbyCode];
          if (game) {
            const playerIndex = game.players.findIndex(p => p.id === playerId);
            if (playerIndex !== -1) {
              const name = game.players[playerIndex].name;
              game.players.splice(playerIndex, 1);
              const idIndex = game.playerIds.indexOf(playerId);
              if (idIndex !== -1) {
                game.playerIds.splice(idIndex, 1);
              }
              game.logs.push(`${name} از لابی خارج شد.`);
              
              if (game.hostId === playerId) {
                if (game.players.length > 0) {
                  game.hostId = game.players[0].id;
                  game.logs.push(`${game.players[0].name} میزبان جدید لابی شد.`);
                } else {
                  delete games[lobbyCode];
                  delete privateRoles[lobbyCode];
                  deleteGameFromDB(lobbyCode);
                  console.log(`Lobby ${lobbyCode} deleted as it became empty.`);
                }
              }
              broadcast(lobbyCode);
            }
          }
          clientLobbies.delete(ws);
          clientPlayerIds.delete(ws);
          break;
        }

        case 'subscribe': {
          const game = games[lobbyCode];
          if (game) {
            clientLobbies.set(ws, lobbyCode);
            clientPlayerIds.set(ws, playerId);
            
            const player = game.players.find(p => p.id === playerId);
            if (player && player.isDisconnected) {
              player.isDisconnected = false;
              game.logs.push(`${player.name} مجدداً به بازی متصل شد.`);
              broadcast(lobbyCode);
            } else {
              ws.send(JSON.stringify({
                type: 'sync',
                data: game,
              }));
            }
          } else {
            ws.send(JSON.stringify({ type: 'error', message: 'Lobby not found.' }));
          }
          break;
        }

        case 'update': {
          const { updates } = payload;
          const game = games[lobbyCode];
          
          if (game) {
            const oldWinner = game.winner;
            const oldPhase = game.phase;
            const oldLib = game.liberalPolicies || 0;
            const oldFas = game.fascistPolicies || 0;
            const oldElection = game.lastElectionResult ? JSON.stringify(game.lastElectionResult) : '';

            console.log(`[AI Narrator] State update event in lobby ${lobbyCode}: phase ${oldPhase} -> ${updates.phase || oldPhase}, lib ${oldLib} -> ${updates.liberalPolicies || oldLib}, fas ${oldFas} -> ${updates.fascistPolicies || oldFas}`);

            Object.assign(game, updates);
            broadcast(lobbyCode);

            const newElection = game.lastElectionResult ? JSON.stringify(game.lastElectionResult) : '';

            // Determine if a narratable event occurred
            let narrationEvent = null;
            let narrationDetail = '';

            if (oldWinner) {
              // Game already won, ignore any subsequent game event narrations
              narrationEvent = null;
            } else if (game.winner && !oldWinner) {
              narrationEvent = game.winner === 'Liberals' ? 'game_win_liberal' : 'game_win_fascist';
              updatePlayersStats(lobbyCode, game.winner);
            } else if (newElection !== oldElection && game.lastElectionResult) {
              narrationEvent = game.lastElectionResult.passed ? 'vote_passed' : 'vote_failed';
              narrationDetail = game.lastElectionResult.nomineeName;
            } else if (game.phase !== oldPhase) {
              if (game.phase === 'roleReveal') {
                narrationEvent = 'setup';
              } else if (game.phase === 'electionNomination') {
                const pres = (game.players || [])[game.presidentIndex];
                const presName = pres ? pres.name : '';
                if ((game.fascistPolicies || 0) >= 3) {
                  narrationEvent = 'president_reveal_hitler_warning';
                } else {
                  narrationEvent = 'president_reveal';
                }
                narrationDetail = presName;
              } else if (game.phase === 'discussion') {
                narrationEvent = 'discussion';
              } else if (game.phase === 'executiveAction') {
                const power = game.activePower;
                if (power === 'execution') {
                  narrationEvent = 'power_execution';
                } else if (power === 'investigateLoyalty') {
                  narrationEvent = 'power_investigate';
                } else if (power === 'callSpecialElection') {
                  narrationEvent = 'power_election';
                } else if (power === 'policyPeek') {
                  narrationEvent = 'power_peek';
                }
              }
            } else if ((game.liberalPolicies || 0) > oldLib) {
              narrationEvent = 'policy_liberal';
            } else if ((game.fascistPolicies || 0) > oldFas) {
              narrationEvent = 'policy_fascist';
            }

            if (narrationEvent) {
              console.log(`[AI Narrator] Event detected: ${narrationEvent}. Requesting narration...`);
              generateNarration(narrationEvent, narrationDetail).then(text => {
                console.log(`[AI Narrator] Text received: "${text}". Broadcasting to client...`);
                game.narration = text;
                game.narrationId = Date.now().toString();
                broadcast(lobbyCode);
              }).catch(e => console.error("[AI Narrator] Error generating narration:", e));
            }
          }
          break;
        }

        case 'savePrivateRoles': {
          const { playerRoles } = payload;
          if (!privateRoles[lobbyCode]) {
            privateRoles[lobbyCode] = {};
          }
          Object.assign(privateRoles[lobbyCode], playerRoles);
          savePrivateRolesToDB(lobbyCode);
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

        case 'loginUser': {
          const { uid, displayName, email, photoUrl } = payload;
          if (!usersCollection) {
            ws.send(JSON.stringify({
              type: 'userProfile',
              data: {
                uid,
                displayName,
                email: email || '',
                photoUrl: photoUrl || 'avatar_1',
                stats: { gamesPlayed: 0, wins: 0, losses: 0, roles: { Liberal: 0, Fascist: 0, 'Secret Hitler': 0 } }
              }
            }));
            break;
          }
          let user = await usersCollection.findOne({ uid });
          if (!user) {
            user = {
              uid,
              displayName,
              email: email || '',
              photoUrl: photoUrl || 'avatar_1',
              stats: {
                gamesPlayed: 0,
                wins: 0,
                losses: 0,
                roles: { Liberal: 0, Fascist: 0, 'Secret Hitler': 0 }
              }
            };
            await usersCollection.insertOne(user);
          }
          ws.send(JSON.stringify({
            type: 'userProfile',
            data: user
          }));
          break;
        }

        case 'updateProfile': {
          const { uid, displayName, photoUrl } = payload;
          if (usersCollection) {
            await usersCollection.updateOne(
              { uid },
              { $set: { displayName, photoUrl } }
            );
            const user = await usersCollection.findOne({ uid });
            ws.send(JSON.stringify({
              type: 'userProfile',
              data: user
            }));
          }
          break;
        }

        case 'getLeaderboard': {
          if (!usersCollection) {
            ws.send(JSON.stringify({ type: 'leaderboard', data: [] }));
            break;
          }
          const topUsers = await usersCollection.find({})
            .sort({ 'stats.wins': -1 })
            .limit(10)
            .toArray();
          
          ws.send(JSON.stringify({
            type: 'leaderboard',
            data: topUsers.map(u => ({
              uid: u.uid,
              displayName: u.displayName,
              photoUrl: u.photoUrl,
              wins: u.stats.wins,
              gamesPlayed: u.stats.gamesPlayed
            }))
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
          if (hasActiveConnection(lobbyCode, playerId, ws)) {
            console.log(`Player ${playerId} closed old connection but has a newer active connection. Not removing.`);
            return;
          }

          const player = game.players.find(p => p.id === playerId);
          if (player) {
            player.isDisconnected = true;
            console.log(`Player ${player.name} disconnected from lobby. Starting 20s grace period.`);
            broadcast(lobbyCode);

            setTimeout(() => {
              const currentGame = games[lobbyCode];
              if (currentGame && currentGame.status === 'lobby') {
                const currentPlayer = currentGame.players.find(p => p.id === playerId);
                if (currentPlayer && currentPlayer.isDisconnected && !hasActiveConnection(lobbyCode, playerId, null)) {
                  const playerIndex = currentGame.players.findIndex(p => p.id === playerId);
                  if (playerIndex !== -1) {
                    const name = currentPlayer.name;
                    currentGame.players.splice(playerIndex, 1);
                    const idIndex = currentGame.playerIds.indexOf(playerId);
                    if (idIndex !== -1) {
                      currentGame.playerIds.splice(idIndex, 1);
                    }
                    currentGame.logs.push(`${name} به دلیل قطع ارتباط از لابی خارج شد.`);
                    
                    if (currentGame.hostId === playerId) {
                      if (currentGame.players.length > 0) {
                        currentGame.hostId = currentGame.players[0].id;
                        currentGame.logs.push(`${currentGame.players[0].name} میزبان جدید لابی شد.`);
                      } else {
                        delete games[lobbyCode];
                        delete privateRoles[lobbyCode];
                        deleteGameFromDB(lobbyCode);
                        console.log(`Lobby ${lobbyCode} deleted as it became empty.`);
                        return;
                      }
                    }
                    broadcast(lobbyCode);
                  }
                }
              }
            }, 20000);
          }
        } else {
          if (hasActiveConnection(lobbyCode, playerId, ws)) {
            console.log(`Player ${playerId} closed old connection but has a newer active connection. Not marking as disconnected.`);
            return;
          }
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
