DELIMITER $$

CREATE TRIGGER trg_player_vehicles_state_update
    AFTER UPDATE ON player_vehicles
    FOR EACH ROW
BEGIN
    -- Only run when state actually changes
    IF OLD.state <> NEW.state THEN

    UPDATE tgmsna_registered_vehicles
    SET mdt_vehicle_status = CASE NEW.state
                                 WHEN 1 THEN 'valid'
                                 WHEN 2 THEN 'impounded'
                                 ELSE mdt_vehicle_status
        END
    WHERE vin = NEW.vin
      AND NEW.state IN (1, 2);

END IF;
END$$

DELIMITER ;