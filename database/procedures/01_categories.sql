-- ============================================================================
-- CATEGORY STORED PROCEDURES
-- ============================================================================

-- SP 1: List all active categories
CREATE OR REPLACE FUNCTION activity.sp_list_categories()
RETURNS TABLE (
    category_id UUID,
    name VARCHAR(100),
    slug VARCHAR(100),
    description TEXT,
    icon_url VARCHAR(500),
    display_order INT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- Query active categories, sorted by display_order and name
    RETURN QUERY
    SELECT
        c.category_id,
        c.name,
        c.slug,
        c.description,
        c.icon_url,
        c.display_order,
        c.is_active,
        c.created_at
    FROM activity.categories c
    WHERE c.is_active = TRUE
    ORDER BY c.display_order ASC, c.name ASC;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_list_categories() IS 'List all active categories sorted by display order';


-- SP 2: Create a new category
CREATE OR REPLACE FUNCTION activity.sp_create_category(
    p_name VARCHAR(100),
    p_slug VARCHAR(100),
    p_description TEXT,
    p_icon_url VARCHAR(500),
    p_display_order INT
)
RETURNS TABLE (
    category_id UUID,
    name VARCHAR(100),
    slug VARCHAR(100),
    description TEXT,
    icon_url VARCHAR(500),
    display_order INT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_category_id UUID;
BEGIN
    -- 1. VALIDATION
    -- Validate slug format (must be lowercase with hyphens/numbers only)
    IF p_slug !~ '^[a-z0-9-]+$' THEN
        RAISE EXCEPTION 'ERR_VALIDATION_INVALID_SLUG_FORMAT'
            USING ERRCODE = '22000';
    END IF;

    -- Check name uniqueness
    IF EXISTS (
        SELECT 1 FROM activity.categories
        WHERE name = p_name
    ) THEN
        RAISE EXCEPTION 'ERR_CONFLICT_CATEGORY_NAME_EXISTS'
            USING ERRCODE = '23505';
    END IF;

    -- Check slug uniqueness
    IF EXISTS (
        SELECT 1 FROM activity.categories
        WHERE slug = p_slug
    ) THEN
        RAISE EXCEPTION 'ERR_CONFLICT_CATEGORY_SLUG_EXISTS'
            USING ERRCODE = '23505';
    END IF;

    -- 2. BUSINESS LOGIC
    -- Insert new category
    INSERT INTO activity.categories (
        name,
        slug,
        description,
        icon_url,
        display_order,
        is_active
    ) VALUES (
        p_name,
        p_slug,
        p_description,
        p_icon_url,
        COALESCE(p_display_order, 0),
        TRUE
    ) RETURNING categories.category_id INTO v_category_id;

    -- 3. RETURN
    RETURN QUERY
    SELECT
        c.category_id,
        c.name,
        c.slug,
        c.description,
        c.icon_url,
        c.display_order,
        c.is_active,
        c.created_at
    FROM activity.categories c
    WHERE c.category_id = v_category_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_create_category IS 'Create a new activity category (admin only)';


-- SP 3: Update an existing category
CREATE OR REPLACE FUNCTION activity.sp_update_category(
    p_category_id UUID,
    p_name VARCHAR(100),
    p_slug VARCHAR(100),
    p_description TEXT,
    p_icon_url VARCHAR(500),
    p_display_order INT,
    p_is_active BOOLEAN
)
RETURNS TABLE (
    category_id UUID,
    name VARCHAR(100),
    slug VARCHAR(100),
    description TEXT,
    icon_url VARCHAR(500),
    display_order INT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_existing_category RECORD;
BEGIN
    -- 1. VALIDATION
    -- Check if category exists
    SELECT * INTO v_existing_category
    FROM activity.categories
    WHERE categories.category_id = p_category_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_NOT_FOUND_CATEGORY'
            USING ERRCODE = '42704';
    END IF;

    -- Validate slug format if provided
    IF p_slug IS NOT NULL AND p_slug !~ '^[a-z0-9-]+$' THEN
        RAISE EXCEPTION 'ERR_VALIDATION_INVALID_SLUG_FORMAT'
            USING ERRCODE = '22000';
    END IF;

    -- Check name uniqueness if changed
    IF p_name IS NOT NULL AND p_name != v_existing_category.name THEN
        IF EXISTS (
            SELECT 1 FROM activity.categories
            WHERE name = p_name AND categories.category_id != p_category_id
        ) THEN
            RAISE EXCEPTION 'ERR_CONFLICT_CATEGORY_NAME_EXISTS'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    -- Check slug uniqueness if changed
    IF p_slug IS NOT NULL AND p_slug != v_existing_category.slug THEN
        IF EXISTS (
            SELECT 1 FROM activity.categories
            WHERE slug = p_slug AND categories.category_id != p_category_id
        ) THEN
            RAISE EXCEPTION 'ERR_CONFLICT_CATEGORY_SLUG_EXISTS'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    -- 2. BUSINESS LOGIC
    -- Update category (only update fields that are provided)
    UPDATE activity.categories
    SET
        name = COALESCE(p_name, name),
        slug = COALESCE(p_slug, slug),
        description = COALESCE(p_description, description),
        icon_url = COALESCE(p_icon_url, icon_url),
        display_order = COALESCE(p_display_order, display_order),
        is_active = COALESCE(p_is_active, is_active),
        updated_at = NOW()
    WHERE categories.category_id = p_category_id;

    -- 3. RETURN
    RETURN QUERY
    SELECT
        c.category_id,
        c.name,
        c.slug,
        c.description,
        c.icon_url,
        c.display_order,
        c.is_active,
        c.created_at,
        c.updated_at
    FROM activity.categories c
    WHERE c.category_id = p_category_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION activity.sp_update_category IS 'Update an existing category (admin only)';
