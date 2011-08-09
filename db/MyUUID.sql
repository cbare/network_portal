delimiter //
CREATE FUNCTION `MyUUID`() RETURNS binary(16)
BEGIN
  DECLARE my_uuid char(37);
  SET my_uuid = UUID();
  RETURN CONCAT(UNHEX(LEFT(my_uuid,8)),UNHEX(MID(my_uuid,10,4)),UNHEX(MID(my_uuid,15,4)),UNHEX(MID(my_uuid,20,4)),UNHEX(RIGHT(my_uuid,12)));
END //
