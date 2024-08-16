# Non destructive schema evolution

Anchor modeling promises the ability to evolve the data structure, without destroying data.

Is this actually a good thing? Instead of migrating the data structure from one consistent state to another, you leave
the old schema as is.

1. Users need to have knowledge about the history of a schema rather than just its current state
2. Applications (may) need to support multiple versions of a schema

# Change data capture

It's easy to effectively track all changes to attributes, when every attribute gets its own table.

However, this also adds overhead to every single query to select the 'current' value.

# Attribute Constraints

When attributes are modeled as separate tables, you lose the ability to enforce not null constraints.

# Current State Views

Using views, you can mimic the schema produced by a lower level of normalization to include just the "current" state
of the system. I.e. Ignoring all of the historical change-data-capture.

## Triggers on current state views

You can also create triggers (insert, update, delete) on the current state views to propagate data updates on the
current state to the historical records.


# Example Queries

## Get all current user names for all users

```sql
select un.name
from users u
join user_names un on un.user_id = u.id
where un.valid_range @> now(); -- @> operator means 'contains' in this context
```

## Get history of names for specific user

```sql
select name, valid_range
from user_names
where user_id = 1
order by valid_range;
```

## Create a user and name

```sql
INSERT INTO user_ids VALUES (DEFAULT) RETURNING id;
INSERT INTO user_names (user_id, name) VALUES (1, 'Grayden');
```

## Atomic update of an attribute
```sql
BEGIN;

UPDATE user_names 
SET valid_range = tstzrange(lower(valid_range), now())
WHERE user_id=1
AND valid_range @> now();

INSERT INTO user_names (user_id, name) VALUES (1, 'Grayden Shand');

COMMIT;
```

## Create user against current-state view
```sql
INSERT INTO users (name, birthday, bio, avatar) VALUES ('Grayden', '1996-10-03', 'Data Engineering', 'https://...');
```

## Update user against current-state view
```sql
UPDATE users SET name = 'Grayden Shand' WHERE id=1;
```

# Conclusions

It seems like there is a viable path forward to produce a schema which captures all changes, while providing an
interface over the current state of a database.

One open question is what the performance implications are of such a design. I would expect:
1. Slower reads due to joins
2. Slower writes due to fanning out to several tables
3. Higher storage costs from retaining all old data and additional indexes

Maybe these can be mitigated or are not materially significant in certain applications. But would be interesting
to do some benchmarking to get a better sense of what the actual tradeoff is.

Additionally, a thin abstraction layer could make this much more feasible to implement.

# TODO:
- [ ] Rename tables to follow pattern `entity__attribute` to avoid plurality issues
- [ ] Add attribute to `room_users` relationship and work out how this should be modeled
    * One idea is to model relationships as entities/anchors
- [ ] Data Validation: triggers check that relationships contain valid references in current states
    * e.g. 'Only valid/current users can be added to a room'
    * "A message can only be sent to a room which the user is currently in" -- probably too complex to generalize
        - maybe not if a message references the relationship of room/user rather than independently referencing a room and user
- [ ] Enforce not null constraints


Modelling Rules
1. A many to many relationship is an entity, a one-to-many relationship is an attribute
2. Every entity is a table
3. Every attribute is a table
