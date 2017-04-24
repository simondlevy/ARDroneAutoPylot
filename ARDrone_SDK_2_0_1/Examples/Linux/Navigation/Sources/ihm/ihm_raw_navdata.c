/*
 * Quick display of Navdata in a tree
 *
 * code adapted from the following GTK tutorial :
 * http://scentric.net/tutorial/treeview-tutorial.html
 */

/* System includes */
#include <sys/time.h>
#include <gtk/gtk.h>

/* SDK includes */
#include <ardrone_api.h>
#include <navdata_common.h>

/* Local declarations */
#include <ihm/ihm_raw_navdata.h>

#define MAX_FIELDS (100)
GtkTreeStore  *treestore;
GtkTreeIter   sequence_number;
GtkTreeIter   navdataBlocks[NAVDATA_NUM_TAGS];
GtkTreeIter   navdataFields[NAVDATA_NUM_TAGS][MAX_FIELDS];

static void addfield(int tag,char * name,char*comment,int*counter)
{
	GtkTreeIter child;
	  gtk_tree_store_append(treestore, &child, &navdataBlocks[tag]);
	  gtk_tree_store_set(treestore, &child,COL_FIELD, name,COL_VALUE,"",COL_COMMENT,comment,-1);
	  navdataFields[tag][*counter]=child;
	  (*counter)++;
}

static void setfield(int tag,char * value,int*counter)
{
	GtkTreeIter child;
	child = navdataFields[tag][*counter];
	gtk_tree_store_set(treestore, &child,COL_VALUE, value,-1);
	(*counter)++;
}


static GtkTreeModel *
create_and_fill_model (void)
{
	int cpt=0;

  treestore = gtk_tree_store_new(NUM_COLS, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING);

  /* Append a top level rows */

  gtk_tree_store_append(treestore, &sequence_number, /*parent element*/NULL);
  gtk_tree_store_set(treestore, &sequence_number,COL_FIELD, "Sequence number",-1);


	#define NAVDATA_OPTION_DEMO(STRUCTURE,NAME,TAG) { \
				gtk_tree_store_append(treestore, &navdataBlocks[TAG], NULL);\
				gtk_tree_store_set   (treestore, &navdataBlocks[TAG], COL_FIELD, #TAG, -1);  }
	#define NAVDATA_OPTION(STRUCTURE,NAME,TAG)      { \
				gtk_tree_store_append(treestore, &navdataBlocks[TAG], NULL); \
				gtk_tree_store_set   (treestore, &navdataBlocks[TAG], COL_FIELD, #TAG, -1);  }
	#define NAVDATA_OPTION_CKS(STRUCTURE,NAME,TAG)

	#include <navdata_keys.h>


  cpt=0;
  addfield(NAVDATA_DEMO_TAG,"ctrl_state","Control State",&cpt);
  addfield(NAVDATA_DEMO_TAG,"phi","deg - Phi",&cpt);
  addfield(NAVDATA_DEMO_TAG,"psi","deg - Psi",&cpt);
  addfield(NAVDATA_DEMO_TAG,"theta","deg - Theta",&cpt);

  cpt=0;
  addfield(NAVDATA_GAMES_TAG,"Double tap counter","times",&cpt);
  addfield(NAVDATA_GAMES_TAG,"Finish line counter","times",&cpt);


  return GTK_TREE_MODEL(treestore);
}



static GtkWidget *
create_view_and_model (void)
{
  GtkTreeViewColumn   *col;
  GtkCellRenderer     *renderer;
  GtkWidget           *view;
  GtkTreeModel        *model;

  view = gtk_tree_view_new();

  /* --- Column #1 --- */
  col = gtk_tree_view_column_new();
  gtk_tree_view_column_set_title(col, "Navdata field");
  gtk_tree_view_append_column(GTK_TREE_VIEW(view), col);

  renderer = gtk_cell_renderer_text_new();
  gtk_tree_view_column_pack_start(col, renderer, TRUE);
  gtk_tree_view_column_add_attribute(col, renderer, "text", COL_FIELD);
  //g_object_set(renderer, "weight", PANGO_WEIGHT_BOLD, "weight-set", TRUE, NULL);
  //g_object_set(renderer, "foreground", "Red", "foreground-set", TRUE, NULL); /* make red */

  /* --- Column #2 --- */
  col = gtk_tree_view_column_new();
  gtk_tree_view_column_set_title(col, "Value");
  gtk_tree_view_append_column(GTK_TREE_VIEW(view), col);
  renderer = gtk_cell_renderer_text_new();
  gtk_tree_view_column_pack_start(col, renderer, TRUE);
  gtk_tree_view_column_add_attribute(col, renderer, "text", COL_VALUE);


  /* --- Column #3 --- */
  col = gtk_tree_view_column_new();
  gtk_tree_view_column_set_title(col, "Comment");
  gtk_tree_view_append_column(GTK_TREE_VIEW(view), col);
  renderer = gtk_cell_renderer_text_new();
  gtk_tree_view_column_pack_start(col, renderer, TRUE);
  gtk_tree_view_column_add_attribute(col, renderer, "text", COL_COMMENT);

  //gtk_tree_view_column_set_cell_data_func(col, renderer, age_cell_data_func, NULL, NULL);


  model = create_and_fill_model();
  gtk_tree_view_set_model(GTK_TREE_VIEW(view), model);
  g_object_unref(model); /* destroy model automatically with view */
  gtk_tree_selection_set_mode(gtk_tree_view_get_selection(GTK_TREE_VIEW(view)), GTK_SELECTION_NONE);

  return view;
}


static GtkWidget *window = NULL;
static GtkWidget *view   = NULL;

gint navdata_ihm_raw_navdata_window_was_destroyed( GtkWidget *widget, GdkEvent  *event, gpointer data )
{
	/* Explanations here : http://www.gtk.org/tutorial1.2/gtk_tut-2.html */
	window = NULL;
	view = NULL;
	return FALSE; /* FALSE means we want the window destryed. TRUE aborts the destroy process. */
}

int
navdata_ihm_raw_navdata_create_window ()
{
	if (!window)
	{
		window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
		if (!window) { return -1; }
		gtk_window_set_default_size(GTK_WINDOW(window), 300, 200);
		gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);

		g_signal_connect(window, "delete_event", GTK_SIGNAL_FUNC(navdata_ihm_raw_navdata_window_was_destroyed), NULL); /* dirty */
		view = create_view_and_model();
		if (!view) { return -1; }

		gtk_container_add(GTK_CONTAINER(window), view);
	}

	gtk_widget_show_all(window);

	return 0;
}

static char buf[1024];
static char buf2[1024];

/* Do an ugly extern thingy because the packed navdata are normally not exposed by the SDK.
 * The unpacked version however does not contain the sequence number ...
 */
extern uint8_t navdata_buffer[NAVDATA_MAX_SIZE];

int
navdata_ihm_raw_navdata_update ( const navdata_unpacked_t* const navdata )
{
	int cpt;
	long int period;
	double frequence,lowpass_frequence;
	static double previous_frequence=0.0f;
	struct timeval current_time;
	static struct timeval previous_time;
	static unsigned long int lastRefreshTime=0;

	navdata_t* packed_navdata = (navdata_t*) &navdata_buffer[0];

	if (!window || !view) { return -1; }

	gettimeofday(&current_time,NULL);

	period = ((current_time.tv_sec-previous_time.tv_sec))*1000000+(current_time.tv_usec-previous_time.tv_usec);
	lastRefreshTime+=period;

	frequence = 1000000.0f / (double)period;
	lowpass_frequence = frequence * 0.005f + previous_frequence * 0.95f;

	if (lastRefreshTime > 100000 /*ms*/)
	{
		lastRefreshTime = 0;

		gdk_threads_enter(); //http://library.gnome.org/devel/gdk/stable/gdk-Threads.html

		snprintf(buf,sizeof(buf),"%d",packed_navdata->sequence);
		snprintf(buf2,sizeof(buf2),"%3.1f Hz",lowpass_frequence);
		gtk_tree_store_set(treestore, &sequence_number,COL_VALUE, buf,COL_COMMENT,buf2,-1);

		cpt=0;
		snprintf(buf,sizeof(buf),"%x",navdata->navdata_demo.ctrl_state);	setfield(NAVDATA_DEMO_TAG,buf,&cpt);
		snprintf(buf,sizeof(buf),"%3.1f",navdata->navdata_demo.phi/1000);	setfield(NAVDATA_DEMO_TAG,buf,&cpt);
		snprintf(buf,sizeof(buf),"%3.1f",navdata->navdata_demo.psi/1000);	setfield(NAVDATA_DEMO_TAG,buf,&cpt);
		snprintf(buf,sizeof(buf),"%3.1f",navdata->navdata_demo.theta/1000);	setfield(NAVDATA_DEMO_TAG,buf,&cpt);


		cpt=0;
		snprintf(buf,sizeof(buf),"%x",navdata->navdata_games.double_tap_counter);	setfield(NAVDATA_GAMES_TAG,buf,&cpt);
		snprintf(buf,sizeof(buf),"%x",navdata->navdata_games.finish_line_counter);	setfield(NAVDATA_GAMES_TAG,buf,&cpt);

		gtk_widget_draw(GTK_WIDGET(view), NULL);
		gdk_threads_leave(); //http://library.gnome.org/devel/gdk/stable/gdk-Threads.html

	}

	previous_time = current_time;
	previous_frequence = lowpass_frequence;
	return C_OK;
}

int navdata_ihm_raw_navdata_init ( void*v ) {return C_OK;}
int navdata_ihm_raw_navdata_release () {return C_OK;}

