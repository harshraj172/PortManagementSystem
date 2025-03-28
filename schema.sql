-- Create User table
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    Username VARCHAR(50) NOT NULL UNIQUE,
    PasswordHash VARCHAR(255) NOT NULL,
    UserType ENUM('Customer','Admin','ShipOwner','Staff') NOT NULL
) ENGINE=InnoDB;

-- Create Staff table
CREATE TABLE Staff (
    StaffID INT PRIMARY KEY,                  -- matches a UserID in the User table
    Address JSON,                             -- complex address: { "city": "...", "state": "...", "zip": "..." }
    PhoneNumber VARCHAR(20),
    Role SET(
        'CraneOperator',
        'ForkliftOperator',
        'Electrician',
        'Mechanic',
        'Rigger'
    ),
    FOREIGN KEY (StaffID) REFERENCES User(UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CHECK (PhoneNumber REGEXP '^[0-9]{10,15}$')
) ENGINE=InnoDB;

-- Create Port table
CREATE TABLE Port (
    PortID INT AUTO_INCREMENT PRIMARY KEY,
    PortName VARCHAR(100) NOT NULL UNIQUE,
    Location VARCHAR(255)
) ENGINE=InnoDB;

-- Create Berth table
CREATE TABLE Berth (
    BerthID INT AUTO_INCREMENT PRIMARY KEY,
    PortID INT NOT NULL,
    LocationName VARCHAR(100),
    MaxLength DECIMAL(10,2),
    MaxDepth DECIMAL(10,2),
    Status ENUM('Available','Occupied','UnderMaintenance') DEFAULT 'Available',
    FOREIGN KEY (PortID) REFERENCES Port(PortID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create Equipment table
CREATE TABLE Equipment (
    EquipmentID INT AUTO_INCREMENT PRIMARY KEY,
    EquipmentName VARCHAR(100) NOT NULL,  
    EquipmentType VARCHAR(50),            
    Status ENUM('Operational','UnderMaintenance') DEFAULT 'Operational',
    LastMaintenanceDate DATETIME,
    NextMaintenanceDue DATETIME
) ENGINE=InnoDB;

-- Create MaintenanceLog table (added AssignmentCost)
CREATE TABLE MaintenanceLog (
    MaintenanceID INT AUTO_INCREMENT PRIMARY KEY,
    MaintenanceDate DATETIME NOT NULL,
    MaintenanceType VARCHAR(50),
    Details VARCHAR(255),
    Status ENUM('Completed','InProgress','Scheduled') DEFAULT 'Scheduled',
    EquipmentID INT NULL,
    BerthID INT NULL,
    StaffID INT NULL,  -- Staff member who performed the maintenance
    AssignmentCost DECIMAL(10,2) DEFAULT 0.00,
    FOREIGN KEY (EquipmentID) REFERENCES Equipment(EquipmentID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    FOREIGN KEY (BerthID) REFERENCES Berth(BerthID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create Ship table with OwnerID referencing a ShipOwner in User
CREATE TABLE Ship (
    ShipID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL UNIQUE,
    Type VARCHAR(50),
    FlagCountry VARCHAR(50),
    OwnerCompany VARCHAR(100),
    Capacity DECIMAL(10,2),
    Length DECIMAL(10,2),
    Width DECIMAL(10,2),
    Draft DECIMAL(10,2),
    OwnerID INT NULL,
    FOREIGN KEY (OwnerID) REFERENCES User(UserID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create Route table
CREATE TABLE Route (
    RouteID INT AUTO_INCREMENT PRIMARY KEY,
    OriginPortID INT NOT NULL,
    DestinationPortID INT NOT NULL,
    Distance DECIMAL(10,2),
    FOREIGN KEY (OriginPortID) REFERENCES Port(PortID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (DestinationPortID) REFERENCES Port(PortID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create ShipRoute table
CREATE TABLE ShipRoute (
    ShipRouteID INT AUTO_INCREMENT PRIMARY KEY,
    ShipID INT NOT NULL,
    RouteID INT NOT NULL,
    CostPerKG DECIMAL(10,2) NOT NULL,
    OwnerCostPerKG DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    Duration INT NOT NULL,
    FOREIGN KEY (ShipID) REFERENCES Ship(ShipID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (RouteID) REFERENCES Route(RouteID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create Cargo table with foreign keys to Port
CREATE TABLE Cargo (
    CargoID INT AUTO_INCREMENT PRIMARY KEY,
    Description VARCHAR(255),
    Weight DECIMAL(10,2),
    Type ENUM('Container','Bulk','Liquid') NOT NULL,
    OriginPortID INT,
    DestinationPortID INT,
    Status ENUM('AtOrigin','InTransit','AtPort') DEFAULT 'AtOrigin',
    FOREIGN KEY (OriginPortID) REFERENCES Port(PortID)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    FOREIGN KEY (DestinationPortID) REFERENCES Port(PortID)
        ON DELETE SET NULL
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create CargoHandlingHistory table
CREATE TABLE CargoHandlingHistory (
    HandlingID INT AUTO_INCREMENT PRIMARY KEY,
    StaffID INT NOT NULL,
    CargoID INT NOT NULL,
    ShipID INT NOT NULL,
    Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    HandlingType ENUM('Loaded','Unloaded','Transferred','Stored') NOT NULL,
    Location VARCHAR(100),
    Remarks VARCHAR(255),
    FOREIGN KEY (StaffID) REFERENCES Staff(StaffID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (CargoID) REFERENCES Cargo(CargoID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (ShipID) REFERENCES Ship(ShipID)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Create Orders table with UNIQUE constraint on CargoID
CREATE TABLE Orders (
    OrderID INT AUTO_INCREMENT PRIMARY KEY,
    CustomerID INT NOT NULL,
    ShipRouteID INT NOT NULL,
    CargoID INT NOT NULL,
    OrderDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    OrderStatus ENUM('Initiated','Confirmed','Completed','Cancelled') DEFAULT 'Initiated',
    Price DECIMAL(10,2) DEFAULT 0.00,     -- Charged to the customer
    Profit DECIMAL(10,2) DEFAULT 0.00,    -- (Price - cost to shipowner)
    PaymentStatus ENUM('Pending','Paid','Refunded') DEFAULT 'Pending',
    FOREIGN KEY (CustomerID) REFERENCES User(UserID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (ShipRouteID) REFERENCES ShipRoute(ShipRouteID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (CargoID) REFERENCES Cargo(CargoID)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    UNIQUE (CargoID)
) ENGINE=InnoDB;

-- Create DailyFinancials table
CREATE TABLE DailyFinancials (
    FinancialDate DATE PRIMARY KEY,
    TotalProfit DECIMAL(10,2) NOT NULL,
    TotalOrders INT NOT NULL,
    AvgOrderPrice DECIMAL(10,2) NOT NULL,
    RecordedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Trigger to calculate order price and profit before inserting into Orders
DELIMITER $$
CREATE TRIGGER trig_calculate_order_price
BEFORE INSERT ON Orders
FOR EACH ROW
BEGIN
    DECLARE routeCost DECIMAL(10,2);
    DECLARE ownerCost DECIMAL(10,2);
    DECLARE cargoWeight DECIMAL(10,2);

    -- Get the cost per kg charged to customer and cost paid to shipowner
    SELECT CostPerKG, OwnerCostPerKG
      INTO routeCost, ownerCost
      FROM ShipRoute
     WHERE ShipRouteID = NEW.ShipRouteID;

    -- Get the cargo weight
    SELECT Weight
      INTO cargoWeight
      FROM Cargo
     WHERE CargoID = NEW.CargoID;

    -- Calculate the price charged to the customer and the profit margin
    SET NEW.Price = routeCost * cargoWeight;
    SET NEW.Profit = (routeCost - ownerCost) * cargoWeight;
END$$
DELIMITER ;

-- Stored procedure to update daily financials
DELIMITER $$
CREATE PROCEDURE UpdateDailyFinancials(IN targetDate DATE)
BEGIN
    DECLARE dailyProfit DECIMAL(10,2);
    DECLARE ordersCount INT;
    DECLARE avgPrice DECIMAL(10,2);
    DECLARE totalStaffCost DECIMAL(10,2);

    -- Sum profit from completed orders for the target day
    SELECT COALESCE(SUM(Profit), 0),
           COUNT(*),
           COALESCE(AVG(Price), 0)
      INTO dailyProfit, ordersCount, avgPrice
      FROM Orders
     WHERE DATE(OrderDate) = targetDate
       AND OrderStatus = 'Completed';

    -- Sum assignment cost for maintenance completed on the target day
    SELECT COALESCE(SUM(AssignmentCost), 0)
      INTO totalStaffCost
      FROM MaintenanceLog
     WHERE DATE(MaintenanceDate) = targetDate
       AND Status = 'Completed';

    -- Subtract the staff cost from daily profit
    SET dailyProfit = dailyProfit - totalStaffCost;

    -- Upsert the calculated values into DailyFinancials
    INSERT INTO DailyFinancials (FinancialDate, TotalProfit, TotalOrders, AvgOrderPrice)
         VALUES (targetDate, dailyProfit, ordersCount, avgPrice)
         ON DUPLICATE KEY UPDATE
             TotalProfit = dailyProfit,
             TotalOrders = ordersCount,
             AvgOrderPrice = avgPrice,
             RecordedAt = CURRENT_TIMESTAMP;
END$$
DELIMITER ;

-- Trigger to ensure a new Staff record corresponds to a User with UserType 'Staff'
DELIMITER $$
CREATE TRIGGER trg_validate_staff_type
BEFORE INSERT ON Staff
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM User WHERE UserID = NEW.StaffID AND UserType = 'Staff'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'StaffID must be of UserType Staff';
    END IF;
END$$
DELIMITER ;

-- Trigger to validate that a Ship's OwnerID refers to a User with UserType 'ShipOwner'
DELIMITER $$
CREATE TRIGGER trg_validate_ship_owner
BEFORE INSERT ON Ship
FOR EACH ROW
BEGIN
    IF NEW.OwnerID IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM User WHERE UserID = NEW.OwnerID AND UserType = 'ShipOwner'
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'OwnerID must refer to a ShipOwner';
        END IF;
    END IF;
END$$
DELIMITER ;
