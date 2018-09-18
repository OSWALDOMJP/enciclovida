class Metamares::ProyectosController < Metamares::MetamaresController

  def index
    @proyectos = Metamares::Proyecto.all
  end

  def show
  end

  def new
    @metamares_proyecto = Metamares::Proyecto.new
  end

  def edit
  end

  def create
    @estatuse = Estatus.new(estatuse_params)

    respond_to do |format|
      if @estatuse.save
        format.html { redirect_to @estatuse, notice: 'Estatus was successfully created.' }
        format.json { render action: 'show', status: :created, location: @estatuse }
      else
        format.html { render action: 'new' }
        format.json { render json: @estatuse.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @estatuse.update(estatuse_params)
        format.html { redirect_to @estatuse, notice: 'Estatus was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @estatuse.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @estatuse.destroy
    respond_to do |format|
      format.html { redirect_to estatuses_url }
      format.json { head :no_content }
    end
  end


  private

  def set_estatuse
    @estatuse = Estatus.find(params[:id])
  end

  def estatuse_params
    params[:estatuse]
  end
end
