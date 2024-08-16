/* CHAT APPLICATION: Anchor* data model (6NF) */
CREATE EXTENSION btree_gist;
BEGIN;

CREATE SCHEMA IF NOT EXISTS history;

-- Entities (anchors)
CREATE TABLE IF NOT EXISTS history.user__id (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)')
);
CREATE TABLE IF NOT EXISTS history.room__id (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)')
);
CREATE TABLE IF NOT EXISTS history.message__id (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)')
);
CREATE TABLE IF NOT EXISTS history.room_user__id (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)')
);

-- Attributes (historized knots)
CREATE TABLE IF NOT EXISTS history.user__name (
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    name TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (user_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.user__birthday (
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    birthday DATE NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (user_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.user__avatar (
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    avatar TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (user_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.user__bio (
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    bio TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (user_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.room__name (
    room_id INT REFERENCES history.room__id(id) NOT NULL,
    name TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.room__image (
    room_id INT REFERENCES history.room__id(id) NOT NULL,
    image TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.room__description (
    room_id INT REFERENCES history.room__id(id) NOT NULL,
    description TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.message__body (
    message_id INT REFERENCES history.message__id(id) NOT NULL,
    body TEXT NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (message_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.message__user_id (
    message_id INT REFERENCES history.message__id(id) NOT NULL,
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (user_id with =, message_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.message__room_id (
    message_id INT REFERENCES history.message__id(id) NOT NULL,
    room_id INT REFERENCES history.room__id(id) NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_id with =, message_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.room_user__room_id (
    room_user_id INT REFERENCES history.room_user__id(id) NOT NULL,
    room_id INT REFERENCES history.room__id(id) NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_user_id with =, room_id with =, valid_range WITH &&)
);

CREATE TABLE IF NOT EXISTS history.room_user__user_id (
    room_user_id INT REFERENCES history.room_user__id(id) NOT NULL,
    user_id INT REFERENCES history.user__id(id) NOT NULL,
    valid_range TSTZRANGE NOT NULL DEFAULT tstzrange(now(), 'infinity', '[)'),
    EXCLUDE USING GIST (room_user_id with =, user_id with =, valid_range WITH &&)
);


-- Current state views
CREATE OR REPLACE VIEW users AS (
    SELECT uid.id, un.name, ua.avatar, ubio.bio, ubir.birthday
    FROM history.user__id uid
    LEFT JOIN history.user__name un on (un.user_id = uid.id AND un.valid_range @> now())
    LEFT JOIN history.user__avatar ua on (ua.user_id = uid.id AND ua.valid_range @> now())
    LEFT JOIN history.user__bio ubio on (ubio.user_id = uid.id AND ubio.valid_range @> now())
    LEFT JOIN history.user__birthday ubir on (ubir.user_id = uid.id AND ubir.valid_range @> now())
    WHERE uid.valid_range @> now()
);

CREATE OR REPLACE FUNCTION InsertUser() RETURNS trigger AS $$
DECLARE
  new_id integer;
BEGIN
  INSERT INTO history.user__id (id) VALUES (DEFAULT) RETURNING id INTO new_id;
  if (NEW.name is not NULL) then
    INSERT INTO history.user__name (user_id, name) VALUES (new_id, NEW.name);
  end if;
  if (NEW.avatar is not NULL) then
    INSERT INTO history.user__avatar (user_id, avatar) VALUES (new_id, NEW.avatar);
  end if;
  if (NEW.bio is not NULL) then
    INSERT INTO history.user__bio (user_id, bio) VALUES (new_id, NEW.bio);
  end if;
  if (NEW.birthday is not NULL) then
    INSERT INTO history.user__birthday (user_id, birthday) VALUES (new_id, NEW.birthday);
  end if;
  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER users_insert INSTEAD OF INSERT ON users
  FOR EACH ROW EXECUTE PROCEDURE InsertUser();

CREATE OR REPLACE FUNCTION UpdateUser() RETURNS trigger AS $$
BEGIN
  
  if (NEW.name != OLD.name) then
    UPDATE history.user__name 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.name is not NULL) then 
        INSERT INTO history.user__name (user_id, name) VALUES (NEW.id, NEW.name);
    end if;
  end if;

  if (NEW.avatar != OLD.avatar) then
    UPDATE history.user__avatar 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.avatar is not NULL) then 
        INSERT INTO history.user__avatar (user_id, avatar) VALUES (NEW.id, NEW.avatar);
    end if;
  end if;

  if (NEW.bio != OLD.bio) then
    UPDATE history.user__bio 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.bio is not NULL) then 
        INSERT INTO history.user__bio (user_id, bio) VALUES (NEW.id, NEW.bio);
    end if;
  end if;

  if (NEW.birthday != OLD.birthday) then
    UPDATE history.user__birthday 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.birthday is not NULL) then 
        INSERT INTO history.user__birthday (user_id, birthday) VALUES (NEW.id, NEW.birthday);
    end if;
  end if;
  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER users_update INSTEAD OF UPDATE ON users
  FOR EACH ROW EXECUTE PROCEDURE UpdateUser();

CREATE OR REPLACE FUNCTION DeleteUser() RETURNS trigger AS $$
BEGIN
    UPDATE history.user__id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE id=OLD.id;

    RETURN OLD;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER users_delete INSTEAD OF DELETE ON users
  FOR EACH ROW EXECUTE PROCEDURE DeleteUser();


CREATE OR REPLACE VIEW rooms AS (
    SELECT rid.id, rn.name, rd.description, ri.image
    FROM history.room__id rid
    LEFT JOIN history.room__name rn on (rn.room_id = rid.id AND rn.valid_range @> now())
    LEFT JOIN history.room__description rd on (rd.room_id = rid.id AND rd.valid_range @> now())
    LEFT JOIN history.room__image ri on (ri.room_id = rid.id AND ri.valid_range @> now())
    WHERE rid.valid_range @> now()
);

CREATE OR REPLACE FUNCTION InsertRoom() RETURNS trigger AS $$
DECLARE
  new_id integer;
BEGIN
  INSERT INTO history.room__id (id) VALUES (DEFAULT) RETURNING id INTO new_id;
  if (NEW.name is not NULL) then
    INSERT INTO history.room__name (room_id, name) VALUES (new_id, NEW.name);
  end if;
  if (NEW.description is not NULL) then
    INSERT INTO history.room__description (room_id, description) VALUES (new_id, NEW.description);
  end if;
  if (NEW.image is not NULL) then
    INSERT INTO history.room__image (room_id, image) VALUES (new_id, NEW.image);
  end if;
  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER rooms_insert INSTEAD OF INSERT ON rooms
  FOR EACH ROW EXECUTE PROCEDURE InsertRoom();

CREATE OR REPLACE FUNCTION UpdateRoom() RETURNS trigger AS $$
BEGIN
  
  if (NEW.name != OLD.name) then
    UPDATE history.room__name 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.name is not NULL) then 
        INSERT INTO history.room__name (room_id, name) VALUES (NEW.id, NEW.name);
    end if;
  end if;

  if (NEW.description != OLD.description) then
    UPDATE history.room__description 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.description is not NULL) then 
        INSERT INTO history.room__description (room_id, description) VALUES (NEW.id, NEW.description);
    end if;
  end if;

  if (NEW.image != OLD.image) then
    UPDATE history.room__image 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.image is not NULL) then 
        INSERT INTO history.room__image (room_id, image) VALUES (NEW.id, NEW.image);
    end if;
  end if;


  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER rooms_update INSTEAD OF UPDATE ON rooms
  FOR EACH ROW EXECUTE PROCEDURE UpdateRoom();

CREATE OR REPLACE FUNCTION DeleteRoom() RETURNS trigger AS $$
BEGIN
    UPDATE history.room__id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE id=OLD.id;

    RETURN OLD;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER rooms_delete INSTEAD OF DELETE ON rooms
  FOR EACH ROW EXECUTE PROCEDURE DeleteRoom();

CREATE OR REPLACE VIEW messages AS (
    SELECT mid.id, mb.body, um.user_id, rm.room_id
    FROM history.message__id mid
    LEFT JOIN history.message__body mb on (mb.message_id = mid.id AND mb.valid_range @> now())
    LEFT JOIN history.message__user_id um on (um.message_id = mid.id AND um.valid_range @> now())
    LEFT JOIN history.message__room_id rm on (rm.message_id = mid.id AND rm.valid_range @> now())
    WHERE mid.valid_range @> now()
);

CREATE OR REPLACE FUNCTION InsertMessage() RETURNS trigger AS $$
DECLARE
  new_id integer;
BEGIN
  INSERT INTO history.message__id (id) VALUES (DEFAULT) RETURNING id INTO new_id;
  if (NEW.body is not NULL) then
    INSERT INTO history.message__body (message_id, body) VALUES (new_id, NEW.body);
  end if;
  if (NEW.user_id is not NULL) then
    INSERT INTO history.message__user_id (message_id, user_id) VALUES (new_id, NEW.user_id);
  end if;
  if (NEW.room_id is not NULL) then
    INSERT INTO history.message__room_id (message_id, room_id) VALUES (new_id, NEW.room_id);
  end if;
  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER messages_insert INSTEAD OF INSERT ON messages
  FOR EACH ROW EXECUTE PROCEDURE InsertMessage();

CREATE OR REPLACE FUNCTION UpdateMessage() RETURNS trigger AS $$
BEGIN
  if (NEW.body != OLD.body) then
    UPDATE history.message__body 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.body is not NULL) then 
        INSERT INTO history.message__body (message_id, body) VALUES (NEW.id, NEW.body);
    end if;
  end if;

  if (NEW.user_id != OLD.user_id) then
    UPDATE history.message__user_id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.user_id is not NULL) then 
        INSERT INTO history.message__user_id (message_id, user_id) VALUES (NEW.id, NEW.user_id);
    end if;
  end if;

  if (NEW.room_id != OLD.room_id) then
    UPDATE history.message__room_id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE room_id=NEW.id
    AND valid_range @> now();

    if (NEW.room_id is not NULL) then 
        INSERT INTO history.message__room_id (message_id, room_id) VALUES (NEW.id, NEW.room_id);
    end if;
  end if;

  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER messages_update INSTEAD OF UPDATE ON messages
  FOR EACH ROW EXECUTE PROCEDURE UpdateMessage();

CREATE OR REPLACE FUNCTION DeleteMessage() RETURNS trigger AS $$
BEGIN
    UPDATE history.message__id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE id=OLD.id;

    RETURN OLD;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER messages_delete INSTEAD OF DELETE ON messages
  FOR EACH ROW EXECUTE PROCEDURE DeleteMessage();

CREATE OR REPLACE VIEW room_users AS (
    SELECT rid.room_id, uid.user_id
    FROM history.room_user__id ruid
    LEFT JOIN history.room_user__room_id rid on (ruid.id = rid.room_user_id AND rid.valid_range @> now())
    LEFT JOIN history.room_user__user_id uid on (ruid.id = uid.room_user_id AND uid.valid_range @> now())
    WHERE ruid.valid_range @> now()
);

CREATE OR REPLACE FUNCTION InsertRoomUser() RETURNS trigger AS $$
DECLARE
  new_id integer;
BEGIN
  INSERT INTO history.room_user__id (id) VALUES (DEFAULT) RETURNING id INTO new_id;
  if (NEW.user_id is not NULL) then
    INSERT INTO history.room_user__user_id (room_user_id, user_id) VALUES (new_id, NEW.user_id);
  end if;
  if (NEW.room_id is not NULL) then
    INSERT INTO history.room_user__room_id (room_user_id, room_id) VALUES (new_id, NEW.room_id);
  end if;
  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER room_users_insert INSTEAD OF INSERT ON room_users
  FOR EACH ROW EXECUTE PROCEDURE InsertRoomUser();

CREATE OR REPLACE FUNCTION UpdateRoomUser() RETURNS trigger AS $$
BEGIN
  if (NEW.user_id != OLD.user_id) then
    UPDATE history.room_user__user_id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE user_id=NEW.id
    AND valid_range @> now();

    if (NEW.user_id is not NULL) then 
        INSERT INTO history.room_user__user_id (room_user_id, user_id) VALUES (NEW.id, NEW.user_id);
    end if;
  end if;

  if (NEW.room_id != OLD.room_id) then
    UPDATE history.room_user__room_id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE room_id=NEW.id
    AND valid_range @> now();

    if (NEW.room_id is not NULL) then 
        INSERT INTO history.room_user__room_id (room_user_id, room_id) VALUES (NEW.id, NEW.room_id);
    end if;
  end if;

  RETURN NEW;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER room_users_update INSTEAD OF UPDATE ON room_users
  FOR EACH ROW EXECUTE PROCEDURE UpdateRoomUser();

CREATE OR REPLACE FUNCTION DeleteRoomUser() RETURNS trigger AS $$
BEGIN
    UPDATE history.room_user__id 
    SET valid_range = tstzrange(lower(valid_range), now())
    WHERE id=OLD.id;

    RETURN OLD;
END; $$ LANGUAGE PLPGSQL;

CREATE OR REPLACE TRIGGER messages_delete INSTEAD OF DELETE ON messages
  FOR EACH ROW EXECUTE PROCEDURE DeleteRoomUser();

COMMIT;