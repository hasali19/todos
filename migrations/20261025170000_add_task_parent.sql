-- A task with a parent_id is a subtask of that task.
-- Deleting subtasks along with their parent is handled by the application.
ALTER TABLE tasks ADD COLUMN parent_id INTEGER REFERENCES tasks (id);

CREATE INDEX tasks_parent_id ON tasks (parent_id);
