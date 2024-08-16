/* CHAT APPLICATION: Basic Data Model (3NF)

Strengths:
- Clarity

Weaknesses:
- No historical data
*/

-- Directory of users
create table users (
    id GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    birthday DATE NOT NULL,
    avatar TEXT NOT NULL,
    bio TEXT NOT NULL
);

-- Directory of rooms
create table rooms (
    id GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name TEXT NOT NULL,
    created TIMESTAMPTZ NOT NULL,
    image TEXT NOT NULL,
    description TEXT NOT NULL
);

-- Current state of users in room
create table room_users (
    user_id TEXT REFERENCES users(id) NOT NULL,
    room_id TEXT REFERENCES rooms(id) NOT NULL
);

-- All messages
create table messages (
    user_id TEXT REFERENCES users(id) NOT NULL,
    room_id TEXT REFERENCES rooms(id) NOT NULL,
    body TEXT NOT NULL
    created_at TIMESTAMPTZ NOT NULL
);
