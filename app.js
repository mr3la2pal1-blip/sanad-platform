document.getElementById("year").textContent=new Date().getFullYear();document.getElementById("interest").addEventListener("click",async()=>{const msg="مرحبًا، أرغب بالتواصل مع فريق منصة سند لمعرفة فرص التطوع أو التعاون المؤسسي.";const status=document.getElementById("status");try{await navigator.clipboard.writeText(msg);status.textContent="تم نسخ رسالة الاهتمام. يمكنك لصقها وإرسالها بالطريقة التي تناسبك."}catch{status.textContent=msg}});if("serviceWorker"in navigator&&location.protocol.startsWith("http"))addEventListener("load",()=>navigator.serviceWorker.register("./sw.js").catch(()=>{}));
// Accessibility and public demo interactions
(()=>{let scale=1;document.getElementById('fontUp')?.addEventListener('click',()=>{scale=Math.min(1.3,scale+.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('fontDown')?.addEventListener('click',()=>{scale=Math.max(.85,scale-.1);document.documentElement.style.fontSize=(16*scale)+'px'});document.getElementById('contrast')?.addEventListener('click',()=>document.body.classList.toggle('high-contrast'));document.getElementById('theme')?.addEventListener('click',()=>document.body.classList.toggle('dark'));document.getElementById('lang')?.addEventListener('click',()=>{alert('النسخة الإنجليزية قيد الإعداد. English version is planned.');});const search=document.getElementById('siteSearch');search?.addEventListener('input',()=>{const q=search.value.trim().toLowerCase();let n=0;document.querySelectorAll('main section').forEach(s=>{const hit=!q||s.innerText.toLowerCase().includes(q);s.hidden=!hit;if(hit)n++});document.getElementById('searchCount').textContent=q?'الأقسام المطابقة: '+n:''});const aidForm=document.getElementById('publicAid');
if(aidForm){aidForm.addEventListener('submit',async e=>{e.preventDefault();const notice=document.getElementById('aidNotice');const fields=aidForm.querySelectorAll('select,input,textarea');const [need,region,contact,details]=Array.from(fields).map(el=>el.value.trim());const submit=aidForm.querySelector('button[type="submit"]');if(!need||!region){notice.textContent='يرجى اختيار نوع الاحتياج وكتابة المنطقة العامة.';return;}submit.disabled=true;notice.textContent='جارٍ إرسال الطلب بأمان...';try{const response=await fetch('https://qnhvahesroyhqiurafmn.supabase.co/rest/v1/public_aid_intake',{method:'POST',headers:{'apikey':'sb_publishable_kaIoj-1y-atRMDkMrkDi6A_RVRsR1ou','Authorization':'Bearer sb_publishable_kaIoj-1y-atRMDkMrkDi6A_RVRsR1ou','Content-Type':'application/json','Prefer':'return=minimal'},body:JSON.stringify({need_type:need,region,contact:contact||null,details:details||null})});if(!response.ok){const errorText=await response.text();throw new Error(errorText||('HTTP '+response.status));}notice.textContent='تم استلام طلبك بنجاح. شكرًا لثقتك بمنصة سند.';aidForm.reset();}catch(error){console.error('Aid request submission failed:',error);notice.textContent='تعذر إرسال الطلب حاليًا. يرجى المحاولة لاحقًا.';}finally{submit.disabled=false;}});}
document.getElementById('volunteerInterest')?.addEventListener('submit',e=>{e.preventDefault();const notice=document.getElementById('volunteerNotice');if(notice)notice.textContent='نموذج التطوع لم يُفعّل بعد.';});})();


// Responsive navigation menu for tablet and mobile
(()=>{
 const header=document.querySelector('body > header');
 if(!header) return;
 const nav=header.querySelector('nav');
 let toggle=header.querySelector('.mobile-menu-toggle');
 if(!nav || !toggle) return;
 nav.id='primary-navigation';
 toggle.setAttribute('aria-controls','primary-navigation');
 const close=()=>{
  header.classList.remove('is-menu-open');
  toggle.setAttribute('aria-expanded','false');
  toggle.innerHTML='<span aria-hidden="true">☰</span><span>القائمة</span>';
 };
 toggle.addEventListener('click',()=>{
  const opening=!header.classList.contains('is-menu-open');
  header.classList.toggle('is-menu-open',opening);
  toggle.setAttribute('aria-expanded',String(opening));
  toggle.innerHTML=opening?'<span aria-hidden="true">✕</span><span>إغلاق</span>':'<span aria-hidden="true">☰</span><span>القائمة</span>';
 });
 header.querySelectorAll('nav a, .outline').forEach(link=>link.addEventListener('click',close));
 document.addEventListener('keydown',event=>{if(event.key==='Escape')close();});
 window.addEventListener('resize',()=>{if(window.innerWidth>820)close();});
})();
