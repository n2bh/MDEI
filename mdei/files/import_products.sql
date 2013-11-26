-- MDEI - Import Products - ver. 0.0.4
-- Copyright (c) 2013 Magentix (http://www.magentix.fr)
-- Magento ver. 1.7, 1.8

# backup:catalog_product_entity
# backup:catalog_product_entity_varchar
# backup:catalog_product_entity_text
# backup:catalog_product_entity_decimal
# backup:catalog_product_entity_int
# backup:catalog_product_website
# backup:catalog_category_product
# backup:cataloginventory_stock_item
# backup:eav_attribute_option
# backup:eav_attribute_option_value
# backup:catalog_product_relation
# backup:catalog_product_super_link
# backup:catalog_product_super_attribute
# backup:catalog_product_super_attribute_label

SET NAMES latin1;
SET SESSION group_concat_max_len = 2048;

# Configuration
SET @_fields = 'type_id,sku,name,url_key,description,short_description,price,weight,options_container,visibility,status,tax_class_id,enable_googlecheckout,is_recurring,color,size,childs,qty,is_in_stock';
SET @_entity_type_id = 4;
SET @_store_id = 0;

# Functions
DROP FUNCTION IF EXISTS `ad`;
DROP FUNCTION IF EXISTS `ex`;
DROP FUNCTION IF EXISTS `id`;
DROP FUNCTION IF EXISTS `bt`;
DROP FUNCTION IF EXISTS `fi`;
DROP FUNCTION IF EXISTS `ms`;
DROP FUNCTION IF EXISTS `ps`;
DROP FUNCTION IF EXISTS `st`;
DROP FUNCTION IF EXISTS `va`;
# Simple product procedures 
DROP PROCEDURE IF EXISTS `setProductEntityId`;
DROP PROCEDURE IF EXISTS `setCategory`;
DROP PROCEDURE IF EXISTS `setWebsites`;
DROP PROCEDURE IF EXISTS `setStock`;
DROP PROCEDURE IF EXISTS `setProductAttributes`;
DROP PROCEDURE IF EXISTS `getAttributeOptionId`;
# Configurable product procedures
DROP PROCEDURE IF EXISTS `linkSimpleToConfigurable`;
DROP PROCEDURE IF EXISTS `setSuperAttributeId`;
DROP PROCEDURE IF EXISTS `addSuperAttribute`;
# Set product
DROP PROCEDURE IF EXISTS `setProduct`;

DELIMITER $$

-- ----------------------------------- --
-- ------------ Functions ------------ --
-- ----------------------------------- --

# Retrieve Attributes With Id
# return : text
CREATE FUNCTION `ad` () RETURNS TEXT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN
        (SELECT CONCAT(group_concat(
            CONCAT(
                '^',attribute_code,'$id',':',attribute_id,'|',
                '^',attribute_code,'$type',':',backend_type,'|',
                '^',attribute_code,'$input',':',frontend_input,'|',
                '^',attribute_code,'$table',':',
                    IF(
                        frontend_input = 'select' AND
                        (source_model IS NULL OR source_model = 'eav/entity_attribute_source_table'), 1, 0
                    )
            )
            SEPARATOR '|'
        ))
        FROM `eav_attribute`
        WHERE `entity_type_id` = @_entity_type_id
        AND FIND_IN_SET (`attribute_code`, @_fields));
END$$

# Set attributes variable
SET @_attributes_id = ad()$$

# Extract value from attributes
# c : code (ex : sku)
# v : value to extract (ex : id / type / input / table)
# return : varchar
CREATE FUNCTION `ex` (c VARCHAR(255), v VARCHAR(255)) RETURNS VARCHAR(255) DETERMINISTIC
BEGIN
    RETURN SUBSTRING_INDEX(SUBSTRING_INDEX(SUBSTRING(@_attributes_id,LOCATE(CONCAT('^',c,'$',v),@_attributes_id)),'|',1),':',-1);
END$$

# Retrieve attribute id by code
# c : code (ex : sku)
# return : int
CREATE FUNCTION `id` (c VARCHAR(255)) RETURNS INT(11) DETERMINISTIC
BEGIN
    RETURN ex(c, 'id');
END$$

# Retrieve attribute backend type by code
# c : code (ex : sku)
# return : varchar
CREATE FUNCTION `bt` (c VARCHAR(255)) RETURNS VARCHAR(255) DETERMINISTIC
BEGIN
    RETURN ex(c, 'type');
END$$

# Retrieve attribute frontend input by code
# c : code (ex : sku)
# return : varchar
CREATE FUNCTION `fi` (c VARCHAR(255)) RETURNS VARCHAR(255) DETERMINISTIC
BEGIN
    RETURN ex(c, 'input');
END$$

# check if source model is table model
# c : code (ex : sku)
# return : int
CREATE FUNCTION `ms` (c VARCHAR(255)) RETURNS INT(11) DETERMINISTIC
BEGIN
    RETURN ex(c, 'table');
END$$

# Retrieve attribute position
# c : code (ex : sku)
# return : int
CREATE FUNCTION `ps` (c VARCHAR(255)) RETURNS INT(11) DETERMINISTIC
BEGIN
    RETURN (SELECT FIND_IN_SET(c, @_fields));
END$$

# Split text
# x : text (ex : field1|field2)
# p : position (ex : 2)
# s : separator (ex : |)
# return : varchar
CREATE FUNCTION `st` (x TEXT, p INT(11), s VARCHAR(255)) RETURNS TEXT DETERMINISTIC
BEGIN
    RETURN (SELECT CASE 
        WHEN CONCAT(x,s) REGEXP CONCAT('((\\',s,').*){',p,'}') 
            THEN SUBSTRING_INDEX(SUBSTRING_INDEX(CONCAT(x,s),s,p),s,-1)
        ELSE ''
    END);
END$$

# Retrieve value
# dp : product data (ex : SKU1|Product Name)
# attribute : code (ex : sku)
# return : text
CREATE FUNCTION `va` (dp TEXT, attribute VARCHAR(255)) RETURNS TEXT DETERMINISTIC
BEGIN
    IF ps(attribute) <> '' THEN
        RETURN st(dp, ps(attribute), '|');
    END IF;
    RETURN '';
END$$

-- ----------------------------------- --
-- ---- Simple product procedures ---- --
-- ----------------------------------- --

# Retrieve product id with sku
# IN product type id (ex : simple)
# IN product sku (ex : SKU001)
# OUT product entity id
CREATE PROCEDURE `setProductEntityId` (IN product_type_id VARCHAR(255), IN product_sku VARCHAR(255), OUT ei INT(11))
BEGIN
    IF(SELECT COUNT(*) FROM `catalog_product_entity` WHERE `sku` = product_sku) = 0 THEN
        IF product_type_id = 'configurable' THEN
            INSERT INTO `catalog_product_entity` (`entity_type_id`, `attribute_set_id`, `type_id`, `sku`, `has_options`, `required_options`, `created_at`, `updated_at`) VALUES (@_entity_type_id, '4', product_type_id, product_sku, 1, 1, now(), now());
        ELSE
            INSERT INTO `catalog_product_entity` (`entity_type_id`, `attribute_set_id`, `type_id`, `sku`, `has_options`, `required_options`, `created_at`, `updated_at`) VALUES (@_entity_type_id, '4', product_type_id, product_sku, 0, 0, now(), now());
        END IF;
    END IF;
    SELECT `entity_id` INTO ei FROM `catalog_product_entity` WHERE `sku` = product_sku GROUP BY `sku`;
END$$

# Assign product to category
# IN product entity id (ex : 10)
# IN category id (ex : 1)
CREATE PROCEDURE `setCategory` (IN ei INT(11), IN category_id INT(11))
BEGIN
    INSERT INTO `catalog_category_product` (`category_id`,`product_id`,`position`) VALUES
        (category_id, ei, 0)
    ON DUPLICATE KEY UPDATE `category_id` = VALUES(`category_id`), `product_id` = VALUES(`product_id`);
END$$

# Set product to Websites
# IN product entity id (ex : 10)
CREATE PROCEDURE `setWebsites` (IN ei INT(11))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE id_website INT;
    DECLARE websites CURSOR FOR SELECT `website_id` FROM `core_website` WHERE `website_id` != 0;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN websites;

    read_loop: LOOP
        FETCH websites INTO id_website;
        IF done THEN
            LEAVE read_loop;
        END IF;
        INSERT INTO `catalog_product_website` (`product_id`,`website_id`) VALUES
            (ei, id_website)
        ON DUPLICATE KEY UPDATE `website_id` = VALUES(`website_id`), `product_id` = VALUES(`product_id`);
    END LOOP;

    CLOSE websites;
END$$

# Set product stock
# IN product entity id (ex : 10)
# IN product qty (ex : 100.0000)
# IN product is in stock (ex : 1)
CREATE PROCEDURE `setStock` (IN ei INT(11), IN product_qty DECIMAL(12,4), IN product_is_in_stock INT(1))
BEGIN
    INSERT INTO `cataloginventory_stock_item` (`product_id`, `stock_id`, `qty`, `is_in_stock`, `low_stock_date`, `stock_status_changed_auto`) VALUES
        (ei, '1', product_qty, product_is_in_stock, NULL, '0')
    ON DUPLICATE KEY UPDATE `qty` = VALUES(`qty`), `is_in_stock` = VALUES(`is_in_stock`);
END$$

# Create or update product attributes
# IN product data (ex : field1|field2)
# IN product attributes (ex : 72|102)
# IN store id (ex : 1)
# IN product entity id (ex : 10)
CREATE PROCEDURE `setProductAttributes` (IN ei INT(11), IN store_id INT(11), IN dp TEXT)
BEGIN
    SET @_iterator = 1;

    attributes: LOOP
        SET @_attribute_code = st(@_fields,@_iterator,',');
        IF @_attribute_code = '' THEN
            LEAVE attributes;
        END IF;
        SET @_value = va(dp,@_attribute_code);
        SET @_backend_type = bt(@_attribute_code);
        SET @_input = fi(@_attribute_code);
        SET @_source_model = ms(@_attribute_code);
        IF @_value <> '' AND @_input <> '' AND @_backend_type <> '' AND @_backend_type <> 'static' THEN
            IF @_source_model = 1 THEN
                CALL getAttributeOptionId(id(@_attribute_code),@_value,0,@_value);
            END IF;
            SET @_insert = CONCAT(
                'INSERT INTO catalog_product_entity_',@_backend_type,
                '(`entity_type_id`,`attribute_id`,`store_id`,`entity_id`,`value`) VALUES (',
                @_entity_type_id,',',id(@_attribute_code),',',store_id,',',ei,',','?'
                ') ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)'
            );
            PREPARE query FROM @_insert;
            EXECUTE query USING @_value;
            DEALLOCATE PREPARE query;
        END IF;
        SET @_iterator = @_iterator + 1;
    END LOOP attributes;
END$$

# Create option if not exists and return option id
# IN attribute id (ex : 5)
# IN option label (ex : red)
# IN store id (ex : 1)
# OUT option id
CREATE PROCEDURE `getAttributeOptionId` (IN attribute_id VARCHAR(255), IN option_label VARCHAR(255), IN store_id INT(11), OUT option_id INT(11))
BEGIN
    IF(SELECT COUNT(*) FROM `eav_attribute_option` o, `eav_attribute_option_value` ov
         WHERE o.`option_id` = ov.`option_id` AND o.`attribute_id` = attribute_id AND ov.`value` = option_label) = 0 THEN
         INSERT INTO `eav_attribute_option` (`attribute_id`, `sort_order`) VALUES (attribute_id, '0');
         INSERT INTO `eav_attribute_option_value` (`option_id`, `store_id`, `value`) VALUES (LAST_INSERT_ID(), store_id, option_label);
    END IF;
    SELECT ov.`option_id` INTO option_id FROM `eav_attribute_option` o, `eav_attribute_option_value` ov
    WHERE o.`option_id` = ov.`option_id` AND o.`attribute_id` = attribute_id AND ov.`value` = option_label AND ov.`store_id` = store_id;
END$$

-- ----------------------------------- --
-- - Configurable product procedures - --
-- ----------------------------------- --

# Link configurable to childs
# IN configurable product entity id (ex : 10)
# IN childs (ex : SKU1,SKU2)
CREATE PROCEDURE `linkSimpleToConfigurable` (IN ei INT(11), IN childs VARCHAR(255))
BEGIN
    DECLARE done INT DEFAULT FALSE;
    DECLARE simple_id INT;
    DECLARE simple_products CURSOR FOR SELECT `entity_id` FROM `catalog_product_entity` WHERE FIND_IN_SET(`sku`, childs);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN simple_products;

    read_loop: LOOP
        FETCH simple_products INTO simple_id;
        IF done THEN
            LEAVE read_loop;
        END IF;
        INSERT INTO `catalog_product_relation` (`parent_id`,`child_id`) VALUES
            (ei, simple_id)
        ON DUPLICATE KEY UPDATE `child_id` = VALUES(`child_id`), `parent_id` = VALUES(`parent_id`);
        INSERT INTO `catalog_product_super_link` (`product_id`,`parent_id`) VALUES
            (simple_id, ei)
        ON DUPLICATE KEY UPDATE `parent_id` = VALUES(`parent_id`), `product_id` = VALUES(`product_id`);
    END LOOP;

    CLOSE simple_products;
END$$

# Get Super Attribute Id
# IN configurable product entity id (ex : 10)
# IN attribute id (ex : 92)
# IN position (ex : 1)
# OUT super attribute id (ex : 10)
CREATE PROCEDURE `setSuperAttributeId` (IN ei INT(11), IN product_attribute_id INT(11), IN attribute_position INT(11), OUT super_attribute_id INT(11))
BEGIN
    IF(SELECT COUNT(*) FROM `catalog_product_super_attribute` WHERE `product_id` = ei AND `attribute_id` = product_attribute_id) = 0 THEN
        INSERT INTO `catalog_product_super_attribute` (`product_id`, `attribute_id`, `position`) VALUES (ei, product_attribute_id, attribute_position);
    END IF;
    SELECT `product_super_attribute_id` INTO super_attribute_id FROM `catalog_product_super_attribute` WHERE `product_id` = ei AND `attribute_id` = product_attribute_id; 
END$$

# Add Super Attribute
# IN configurable product entity id (ex : 10)
# IN store id (ex : 1)
CREATE PROCEDURE `addSuperAttribute` (IN ei INT(11), IN store_id INT(11), IN product_attribute_id INT(11))
BEGIN
    CALL setSuperAttributeId(ei, product_attribute_id, 1, @_super_attribute_id);
    INSERT INTO `catalog_product_super_attribute_label` (`product_super_attribute_id`, `store_id`, `use_default`, `value`) VALUES
        (@_super_attribute_id, store_id, '1', '')
    ON DUPLICATE KEY UPDATE `product_super_attribute_id` = VALUES(`product_super_attribute_id`), `value` = VALUES(`value`);
END$$

-- ----------------------------------- --
-- ----------- Set product ----------- --
-- ----------------------------------- --

# Add Product
# IN product data (ex : field1|field2)
# IN configurable product attrbutes (ex : color,size)
CREATE PROCEDURE `setProduct` (IN dp TEXT, IN ca VARCHAR(255))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
    END;
    START TRANSACTION;

    SET @_type_id = va(dp,'type_id');
    SET @_childs = va(dp,'childs');

    CALL setProductEntityId(@_type_id, va(dp,'sku'), @_entity_id);

    CALL setProductAttributes(@_entity_id, @_store_id, dp);
    CALL setStock(@_entity_id, va(dp,'qty'), va(dp,'is_in_stock'));
    CALL setWebsites(@_entity_id);
    
    IF @_type_id = 'configurable' AND @_childs != '' AND ca != '' THEN
        SET @_iterator = 1;

        attributes: LOOP
            SET @_attribute_code = st(ca,@_iterator,',');
            IF @_attribute_code = '' THEN
                LEAVE attributes;
            END IF;
            CALL addSuperAttribute(@_entity_id, @_store_id, id(@_attribute_code));
            SET @_iterator = @_iterator + 1;
        END LOOP attributes;

        CALL linkSimpleToConfigurable(@_entity_id, @_childs);
    END IF;

    COMMIT;
END$$

DELIMITER ;

-- ----------------------------------- --
-- ------------- Example ------------- --
-- ----------------------------------- --

# CALL setProduct("simple|SKU001-1|T-Shirt Magento - Yellow - S|t-shirt-magento-yellow-s|T-shirt Magento Yellow S|T-shirt Magento Yellow S|0.00|1000|container2|1|1|0|0|0|Yellow|S||100|1","");
# CALL setProduct("simple|SKU001-2|T-Shirt Magento - Yellow - M|t-shirt-magento-yellow-m|T-shirt Magento Yellow M|T-shirt Magento Yellow M|0.00|1000|container2|1|1|0|0|0|Yellow|M||100|1","");
# CALL setProduct("simple|SKU001-3|T-Shirt Magento - Yellow - L|t-shirt-magento-yellow-l|T-shirt Magento Yellow L|T-shirt Magento Yellow L|0.00|1000|container2|1|1|0|0|0|Yellow|L||100|1","");
# CALL setProduct("simple|SKU001-4|T-Shirt Magento - Blue - S|t-shirt-magento-blue-s|T-shirt Magento Blue S|T-shirt Magento blue S|0.0000|1000|container2|1|1|0|0|0|Blue|S||100|1","");
# CALL setProduct("simple|SKU001-5|T-Shirt Magento - Blue - M|t-shirt-magento-blue-m|T-shirt Magento Blue M|T-shirt Magento blue M|0.0000|1000|container2|1|1|0|0|0|Blue|M||100|1","");
# CALL setProduct("simple|SKU001-6|T-Shirt Magento - Blue - L|t-shirt-magento-blue-l|T-shirt Magento Blue L|T-shirt Magento blue L|0.0000|1000|container2|1|1|0|0|0|Blue|L||100|1","");
# CALL setProduct("configurable|SKU001|T-Shirt Magento|t-shirt-magento|T-shirt Magento|T-shirt Magento|29.00|1000|container1|4|1|0|0||||SKU001-1,SKU001-2,SKU001-3,SKU001-4,SKU001-5,SKU001-6|0|1","color,size");

-- ----------------------------------- --
-- -------------- Data --------------- --
-- ----------------------------------- --

# {{DATA}} #