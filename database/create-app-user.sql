-- Run only after the poc_app user has been created
-- using a securely generated password.

GRANT SELECT, INSERT, UPDATE, DELETE
ON react_node_app.*
TO 'poc_app'@'%';

SHOW GRANTS FOR 'poc_app'@'%';
