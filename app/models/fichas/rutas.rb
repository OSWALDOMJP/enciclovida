class Fichas::Rutas < ActiveRecord::Base

	self.table_name = "#{CONFIG.bases.fichasespecies}.rutas"
	self.primary_keys = :especieId,  :categoriaruta

end
