-- Function to update stock
CREATE OR REPLACE FUNCTION actualizar_stock_insumos()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE lotes_insumos
    SET stock_actual = stock_actual - NEW.cantidad_usada
    WHERE id = NEW.id_lote_insumo;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to execute after insert on consumo_insumos
DROP TRIGGER IF EXISTS trigger_descontar_stock ON consumo_insumos;
CREATE TRIGGER trigger_descontar_stock
AFTER INSERT ON consumo_insumos
FOR EACH ROW
EXECUTE FUNCTION actualizar_stock_insumos();
