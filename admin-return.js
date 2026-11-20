const link=document.getElementById('adminReturnLink');
if(link){
  try{
    const {createClient}=await import('https://esm.sh/@supabase/supabase-js@2');
    const db=createClient('https://vovpbesmqgvfpjxslzbx.supabase.co','sb_publishable_1T4fLsk02CYnxnJOFVGhtw_Mh-t9V3j');
    const {data:{session}}=await db.auth.getSession();
    if(session?.user){
      const {data:profile,error}=await db.from('profiles').select('role,is_active').eq('id',session.user.id).single();
      if(!error&&profile?.role==='admin'&&profile.is_active===true)link.hidden=false;
    }
  }catch(error){
    console.warn('Admin return link remains hidden:',error);
  }
}